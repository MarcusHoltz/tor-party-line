<a href="https://gitlab.com/MarcusHoltz/tor-party-line"><img src="https://raw.githubusercontent.com/MarcusHoltz/marcusholtz.github.io/refs/heads/main/assets/img/header/header--partyline--tor-onion-router-overlay-network.jpg" alt="Tor Party Line"></a>

<table><tr>
<td><a href="https://www.torproject.org/"><img src="https://img.shields.io/badge/built%20for-Tor-7d4698?style=for-the-badge" alt="Built for Tor"></a></td>
<td><a href="https://gitlab.com/MarcusHoltz/tor-party-line/-/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="License: MIT"></a></td>
<td><a href="https://gitlab.com/MarcusHoltz/tor-party-line"><img src="https://img.shields.io/badge/source-GitLab-orange?style=for-the-badge&logo=gitlab" alt="Source: GitLab"></a></td>
<td><a href="https://github.com/MarcusHoltz/tor-party-line"><img src="https://img.shields.io/badge/source-GitHub-black?style=for-the-badge&logo=github" alt="Source: GitHub"></a></td>
</tr></table>

# marcusholtz/tor-party-line

Encrypted push-to-talk voice and group party line over [Tor hidden services](https://community.torproject.org/onion-services/overview/). No accounts, no phone numbers, no third-party servers.

## Supported Architectures

| Architecture | Tag |
| :---: | --- |
| x86-64 | `amd64` |

## Quick Start: Interactive Calling

Pull and run the interactive menu. Make calls, listen for calls, set secrets, test audio.

### docker-compose (recommended)

Save as `docker-compose.yml`, then run `docker compose run --rm partyline`:

```yaml
services:
  partyline:
    image: marcusholtz/tor-party-line:latest
    container_name: tor-party-line
    restart: unless-stopped
    stdin_open: true
    tty: true
    security_opt:
      - label:disable
    devices:
      - /dev/snd:/dev/snd
    volumes:
      - ./data/docker/tor:/var/lib/tor
      - ./data/docker/partyline:/data/.partyline
      - ./secrets:/run/secrets:ro
      - ${XDG_RUNTIME_DIR:-/run/user/1000}/pulse:/run/user/${UID:-1000}/pulse
    environment:
      - TERM=${TERM:-xterm-256color}
      - SHARED_SECRET_FILE=/run/secrets/shared_secret.txt
      - PULSE_SERVER=unix:/run/user/${UID:-1000}/pulse/native
      - XDG_RUNTIME_DIR=/run/user/${UID:-1000}
```

### docker cli

```bash
docker run -it --rm \
  --name tor-party-line \
  --security-opt label:disable \
  --device /dev/snd:/dev/snd \
  -v ./data/docker/tor:/var/lib/tor \
  -v ./data/docker/partyline:/data/.partyline \
  -v ./secrets:/run/secrets:ro \
  -v ${XDG_RUNTIME_DIR}/pulse:/run/user/$(id -u)/pulse \
  -e TERM=${TERM} \
  -e SHARED_SECRET_FILE=/run/secrets/shared_secret.txt \
  -e PULSE_SERVER=unix:/run/user/$(id -u)/pulse/native \
  -e XDG_RUNTIME_DIR=/run/user/$(id -u) \
  marcusholtz/tor-party-line:latest
```

### First run

1. Tor bootstraps (1-3 min first time, progress shown)
2. Your permanent `.onion` address appears
3. Press **1** to set a shared secret (both sides need the same one)
4. Share your `.onion` + secret, one side listens (4), the other calls (5)

Your `.onion` keys persist in `./data/docker/tor/` across restarts.

## Quick Start: Always-On Relay

Run a persistent group bridge. Callers dial your `.onion` and are bridged together.

### docker-compose

Using the same `docker-compose.yml` above:

```bash
# Start relay in background (Tor bootstraps, group bridge opens)
docker compose up -d

# Watch live activity
docker compose logs -f

# Stop
docker compose down
```

### docker cli

```bash
docker run -d \
  --name tor-party-line-relay \
  --restart unless-stopped \
  --security-opt label:disable \
  -v ./data/docker/tor:/var/lib/tor \
  -v ./data/docker/partyline:/data/.partyline \
  -v ./secrets:/run/secrets:ro \
  -e SHARED_SECRET_FILE=/run/secrets/shared_secret.txt \
  marcusholtz/tor-party-line:latest \
  relay
```

No audio mounts needed for relay mode (it forwards encrypted blobs, never decodes audio).

## Parameters

| Parameter | Function |
| :---: | --- |
| `-e SHARED_SECRET_FILE` | Path to secret file inside container. Default: `/run/secrets/shared_secret.txt` |
| `-e OPUS_BITRATE=16` | Opus encoding bitrate in kbps |
| `-e LISTEN_PORT=7777` | TCP listen port |
| `-e TOR_SOCKS_PORT=9050` | Tor SOCKS proxy port |
| `-e CIPHER=aes-256-cbc` | Encryption cipher (21 options) |
| `-e HMAC_AUTH=1` | HMAC-sign protocol messages (`0`/`1`) |
| `-e SINGLE_HOP=0` | Faster, less anonymous (`0`/`1`) |
| `-e SNOWFLAKE_ENABLED=0` | Censorship-circumvention bridge (`0`/`1`) |
| `-e AUTO_LISTEN=0` | Auto-listen when Tor boots (`0`/`1`) |
| `-e SHOW_CIRCUIT=0` | Show circuit countries in call header (`0`/`1`) |
| `-e EXCLUDE_NODES=` | Tor ExcludeNodes, e.g. `{US},{GB}` |
| `-e ALSA_DEVICE=` | Force ALSA capture device, e.g. `plughw:2,0` |
| `-e ALSA_PLAY_DEVICE=` | Force ALSA playback device, e.g. `plughw:0,0` |
| `-e PULSE_SERVER` | PulseAudio/PipeWire socket path |
| `-v /var/lib/tor` | .onion keys + Tor state (persistent) |
| `-v /data/.partyline` | App config + encrypted secret (persistent) |
| `-v /run/secrets` | Shared secret file (read-only mount) |
| `-v /run/user/$UID/pulse` | Host audio socket |
| `--device /dev/snd` | ALSA fallback for bare-ALSA hosts |

## Shared Secret

The secret is **not** an environment variable. It is a bind-mounted file:

```bash
mkdir -p secrets
echo -n 'your-shared-secret' > secrets/shared_secret.txt
chmod 600 secrets/shared_secret.txt
```

Per-run override: `docker compose run --rm partyline call <addr> --secret 'my-secret'`

A relay does not need a secret.

## Audio

Audio routes through the host's PulseAudio/PipeWire socket. ALSA direct (`/dev/snd`) is the fallback.

```bash
arecord -l    # find capture devices on the host
aplay -l      # find playback devices on the host
```

## Security

| Property | Detail |
| --- | --- |
| Encryption | AES-256-CBC + PBKDF2 + HMAC-SHA256 |
| Relay | Zero-knowledge: forwards blobs, never has the secret |
| Authentication | `.onion` address + pre-shared secret |
| Forward secrecy | None; rotate secrets between conversations |
| Source | Single bash script, no binaries, no telemetry |

## The Party Line Trifecta

Three networks, same app, same encryption:

| | | |
|---|---|---|
| [![Tor Party Line](https://raw.githubusercontent.com/MarcusHoltz/marcusholtz.github.io/refs/heads/main/assets/img/header/header--partyline--tor-onion-router-overlay-network.jpg)](https://hub.docker.com/r/marcusholtz/tor-party-line) | [![I2P Party Line](https://raw.githubusercontent.com/MarcusHoltz/marcusholtz.github.io/refs/heads/main/assets/img/header/header--partyline--invisible-internet-project-i2p-garlic-roter.jpg)](https://hub.docker.com/r/marcusholtz/i2p-party-line) | [![Reticulum Party Line](https://raw.githubusercontent.com/MarcusHoltz/marcusholtz.github.io/refs/heads/main/assets/img/header/header--partyline--reticulum-network-stack.jpg)](https://hub.docker.com/r/marcusholtz/reticulum-party-line) |
| **Tor Party Line** | [I2P Party Line](https://hub.docker.com/r/marcusholtz/i2p-party-line) | [Reticulum Party Line](https://hub.docker.com/r/marcusholtz/reticulum-party-line) |

## License

MIT
