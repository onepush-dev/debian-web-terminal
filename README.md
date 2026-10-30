# Debian Web Terminal — Debian 12 (bookworm) shell in your browser and over SSH, sharing one tmux session. Deploy on Railway with one click.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/TEMPLATE_CODE)

A persistent **Debian 12 (bookworm)** box on Railway. Open the public URL for a full terminal in the browser ([ttyd](https://github.com/tsl0922/ttyd) 1.7.7, HTTP basic auth), or SSH in through a Railway TCP proxy. Both land in the **same tmux session** (`main`), so a job you start in the browser is still running when you SSH in from your laptop, and the other way round. `/home` lives on a volume. No deploy-time input: the login password is generated per deploy.

## Why this template
- **Debian 12 (bookworm), pinned.** Base `debian:bookworm-20261027@sha256:d74df7598108a173a621eda4d58a2adbf850b2d9a9d81bc2cca1a6c21174a880`; ttyd 1.7.7 static binary verified by SHA-256. Image: `ghcr.io/onepush-dev/debian-web-terminal:12-ttyd1.7.7`.
- **Browser + SSH, one session.** ttyd attaches to tmux session `main`; interactive SSH logins auto-attach to the same session (`TMUX_AUTO_ATTACH`).
- **Persistent home.** Volume at `/home`; SSH host keys are stored on it too, so the fingerprint survives redeploys.
- **Secure defaults.** One generated password (`TERMINAL_PASSWORD`, 24 chars) protects both ttyd and SSH; root login over SSH disabled; only `TERMINAL_USER` may log in.
- **Useful toolbox.** sudo, git, curl, wget, jq, nano, vim-tiny, htop, rsync, zip/unzip, dnsutils, ping, man.

## Service
| Service | Image | Ports | Volume | Notes |
|---|---|---|---|---|
| Debian | `ghcr.io/onepush-dev/debian-web-terminal:12-ttyd1.7.7` | 7681 HTTP (public domain), 2222 SSH (TCP proxy) | `/home` | Restart ALWAYS. No HTTP healthcheck because every path needs basic auth |

## Variables
Exact template values: [`railway/template-variables.env`](railway/template-variables.env).

| Variable | Template value | Notes |
|---|---|---|
| PORT | `7681` | ttyd web terminal port |
| SSH_PORT | `2222` | sshd port behind the Railway TCP proxy |
| TERMINAL_USER | `debian` | Login user for browser and SSH (created at start if you change it) |
| TERMINAL_PASSWORD | `${{secret(24)}}` | Password for browser basic auth and SSH |
| SSH_PASSWORD_AUTH | `true` | Set `false` after adding keys to allow key-only SSH |
| SUDO_NOPASSWD | `true` | Passwordless sudo for `TERMINAL_USER` |
| TMUX_SESSION | `main` | Shared tmux session name |
| TMUX_AUTO_ATTACH | `true` | Interactive SSH logins attach to the shared session |
| TERMINAL_TITLE | `Debian 12` | Browser tab title |
| TTYD_FONT_SIZE | `15` | Browser terminal font size |
| TTYD_MAX_CLIENTS | `0` | Max simultaneous browser clients (0 = unlimited) |
| TZ | `UTC` | Container timezone |
| SSH_AUTHORIZED_KEYS | _(not set)_ | Optional: add it with one or more public keys separated by `;` |

## How to use
1. Click **Deploy on Railway** and wait for the service to come online (under a minute).
2. Copy `TERMINAL_PASSWORD` from the service's **Variables** tab.
3. **Browser:** open the public URL, sign in as `debian` with that password.
4. **SSH:** find the TCP proxy under **Settings → Networking** (e.g. `tokaido.proxy.rlwy.net:45385`) and run `ssh -p <port> debian@<host>`.

## Notes
- Only `/home` persists. Packages installed with `apt` live in the container layer and are gone after a redeploy; install tools into `~/.local` or bake them into a fork of the Dockerfile.
- The container is not a full VM: no systemd, no Docker-in-Docker, no inbound UDP.
- Railway terminates TLS for the web terminal. SSH is end-to-end encrypted by SSH itself.
- To rotate the password, change `TERMINAL_PASSWORD` and redeploy.

## License
Debian is a registered trademark of Software in the Public Interest, Inc. ttyd is MIT licensed. This repository (Dockerfile, scripts, Railway config) is MIT.
