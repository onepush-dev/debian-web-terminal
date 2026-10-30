# Attach interactive SSH logins to the shared tmux session (same one the browser uses).
[ -f /etc/railway-terminal.env ] && . /etc/railway-terminal.env
if [ -n "${SSH_CONNECTION:-}" ] && [ -z "${TMUX:-}" ] && [ "${TMUX_AUTO_ATTACH:-true}" = "true" ] && [ -t 0 ] && [ -z "${SSH_ORIGINAL_COMMAND:-}" ]; then
  exec tmux new-session -A -s "${TMUX_SESSION:-main}"
fi
