#!/bin/bash
# Debian 12 web terminal entrypoint (runs as root, drops each session to $TERMINAL_USER).
set -euo pipefail

U="${TERMINAL_USER:-debian}"
PASS="${TERMINAL_PASSWORD:-}"
PORT="${PORT:-7681}"
SSH_PORT="${SSH_PORT:-2222}"
SESSION="${TMUX_SESSION:-main}"
PERSIST=/home/.railway-terminal

if [ -z "$PASS" ]; then
  echo "TERMINAL_PASSWORD is empty; refusing to start an unauthenticated terminal" >&2
  exit 1
fi

# 1. User. Debian images ship no regular user; create it (uid 1000 on first run).
if ! id "$U" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G sudo "$U"
fi
usermod -s /bin/bash "$U" >/dev/null 2>&1 || true
usermod -aG sudo "$U" >/dev/null 2>&1 || true
echo "$U:$PASS" | chpasswd
if [ "${SUDO_NOPASSWD:-true}" = "true" ]; then
  echo "$U ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-terminal
else
  echo "$U ALL=(ALL) ALL" > /etc/sudoers.d/90-terminal
fi
chmod 440 /etc/sudoers.d/90-terminal

# 2. Home on the volume (mounted at /home). Seed it the first time.
HOMEDIR=$(getent passwd "$U" | cut -d: -f6)
if [ ! -d "$HOMEDIR" ] || [ -z "$(ls -A "$HOMEDIR" 2>/dev/null)" ]; then
  mkdir -p "$HOMEDIR"
  if [ -d "/opt/home-skel/$U" ]; then cp -an "/opt/home-skel/$U/." "$HOMEDIR/"; fi
  cp -an /etc/skel/. "$HOMEDIR/"
fi
chown "$U:$U" "$HOMEDIR"
chmod 750 "$HOMEDIR"

# 3. SSH host keys persisted on the volume so the fingerprint survives redeploys.
mkdir -p "$PERSIST/ssh"
chmod 700 "$PERSIST"
if [ ! -f "$PERSIST/ssh/ssh_host_ed25519_key" ]; then
  ssh-keygen -q -t ed25519 -N "" -f "$PERSIST/ssh/ssh_host_ed25519_key"
  ssh-keygen -q -t rsa -b 3072 -N "" -f "$PERSIST/ssh/ssh_host_rsa_key"
fi
cp "$PERSIST"/ssh/ssh_host_* /etc/ssh/
chmod 600 /etc/ssh/ssh_host_*_key

# 4. Optional public keys.
if [ -n "${SSH_AUTHORIZED_KEYS:-}" ]; then
  install -d -m 700 -o "$U" -g "$U" "$HOMEDIR/.ssh"
  touch "$HOMEDIR/.ssh/authorized_keys"
  printf '%s\n' "$SSH_AUTHORIZED_KEYS" | tr ';' '\n' | sed '/^\s*$/d' | while read -r k; do
    grep -qxF "$k" "$HOMEDIR/.ssh/authorized_keys" || echo "$k" >> "$HOMEDIR/.ssh/authorized_keys"
  done
  chown "$U:$U" "$HOMEDIR/.ssh/authorized_keys"; chmod 600 "$HOMEDIR/.ssh/authorized_keys"
fi

PWAUTH=yes; [ "${SSH_PASSWORD_AUTH:-true}" = "true" ] || PWAUTH=no
cat > /etc/ssh/sshd_config.d/20-runtime.conf <<CFG
Port $SSH_PORT
PasswordAuthentication $PWAUTH
AllowUsers $U
CFG

# Settings for login shells (SSH sessions don't inherit container env).
cat > /etc/railway-terminal.env <<CFG
TMUX_SESSION=$SESSION
TMUX_AUTO_ATTACH=${TMUX_AUTO_ATTACH:-true}
CFG
[ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/$TZ" ] && ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime

# 5. sshd in the background, ttyd in the foreground (tini reaps both).
/usr/sbin/sshd -t
/usr/sbin/sshd -D -e &
echo "sshd listening on :$SSH_PORT (password auth: $PWAUTH)"

echo "ttyd listening on :$PORT; user $U; tmux session '$SESSION'"
exec /usr/local/bin/ttyd \
  --port "$PORT" --ipv6 --writable \
  --credential "$U:$PASS" \
  --max-clients "${TTYD_MAX_CLIENTS:-0}" \
  -t titleFixed="${TERMINAL_TITLE:-Debian 12}" -t fontSize="${TTYD_FONT_SIZE:-15}" \
  su - "$U" -s /bin/bash -c "TMUX_AUTO_ATTACH=false exec tmux new-session -A -s '$SESSION'"
