#!/bin/bash
# Starts Claude Code's Remote Control server in tmux and keeps the container alive while it runs.
set -euo pipefail

for dir in "$HOME" /projects; do
  [ -w "$dir" ] || {
    echo "$dir is not writable by uid $(id -u):$(id -g); fix the owner of the mounted folder" >&2
    exit 1
  }
done
mkdir -p "$HOME/.local/bin"

# First start: install Claude Code into the persisted home. After that its own auto-updater
# keeps it current; a new version takes effect the next time Claude starts.
if ! command -v claude >/dev/null 2>&1; then
  echo "Installing Claude Code into $HOME/.local"
  curl -fsSL --proto '=https' https://claude.ai/install.sh | bash
fi
echo "Claude Code $(claude --version 2>/dev/null || echo 'version unknown')"

# Scheduled headless jobs: a crontab at $HOME/crontab, run by supercronic (reloaded when edited).
if [ -f "$HOME/crontab" ]; then
  if supercronic -test "$HOME/crontab" >/dev/null 2>&1; then
    supercronic -inotify "$HOME/crontab" &
    echo "Scheduled jobs: running $HOME/crontab"
  else
    echo "Scheduled jobs: $HOME/crontab is invalid, skipped (check with: supercronic -test $HOME/crontab)" >&2
  fi
fi

# Remote Control server mode: the Claude app can start new sessions on demand. Session names
# start with RC_NAME. If Claude exits (for example before the first login), a shell is left in
# tmux for setup; restart the container afterwards.
RC_NAME=${RC_NAME:-unraid}
tmux new-session -d -s main -c /projects -e "RC_NAME=$RC_NAME" \
  'claude remote-control --remote-control-session-name-prefix "$RC_NAME"; exec bash'
echo "Claude Code Remote Control started in tmux session 'main' (attach: tmux attach -t main)"

# Chats from the last 14 days come back as live Remote Control sessions, one tmux window each.
chat-sessions reattach || echo "Reattaching chats failed" >&2

trap 'tmux kill-server 2>/dev/null; exit 0' TERM INT
while tmux has-session -t =main 2>/dev/null; do
  sleep 5 &
  wait $!
done
echo "tmux session 'main' ended"
