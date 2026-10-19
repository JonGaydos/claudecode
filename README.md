# claudecode

Always-on Claude Code in a container on Unraid, driven from the Claude app or claude.ai/code through
Remote Control in server mode.

## How it works

- **Image**: Debian (Node 24 slim) with tmux, git, ssh, curl, jq, ripgrep, Python, uv and supercronic.
  Rebuilt weekly by GitHub Actions and published to `ghcr.io/jongaydos/claudecode`, so Unraid
  shows an update when the base OS has security fixes.
- **Claude Code**: not in the image. On first start, `start.sh` installs it with Anthropic's official
  installer into the persisted home. Claude Code's auto-updater keeps it current; a new version takes
  effect the next time Claude starts (container restart or update).
- **Session**: `claude remote-control` (server mode) runs in tmux session `main`, from `/projects`.
  The Claude app can start new sessions on demand; names start with `RC_NAME`.
- **Scheduled jobs**: if `$HOME/crontab` exists, supercronic runs it, for example
  `10 3 * * * cd /projects && claude -p "..."`.
- **Security**: runs as 99:100, all capabilities dropped, `no-new-privileges`, bridge network, no
  ports. Only the two mounted folders are visible.

## Paths

| Container | Host (default) | Holds |
| --- | --- | --- |
| `/home/claude` | `/mnt/user/appdata/claude-code/home` | login, settings, CLAUDE.md, skills, scripts, key files, Claude Code |
| `/projects` | `/mnt/user/appdata/claude-code/projects` | working folder |

## Install on Unraid

1. Create the folders, owned by the container user:

   ```bash
   mkdir -p /mnt/user/appdata/claude-code/home /mnt/user/appdata/claude-code/projects
   chown -R 99:100 /mnt/user/appdata/claude-code
   ```

2. Add the container with the values in `unraid/claude-code.xml` (Docker > Add Container), or copy
   that file to `/boot/config/plugins/dockerMan/templates-user/my-claude-code.xml` and pick it from
   the template list.
3. First start: Claude Code installs, then `claude remote-control` exits because nobody is signed in,
   leaving a shell in tmux. Open the container console and run:

   ```bash
   tmux attach -t main
   claude          # sign in with /login, then /exit
   claude remote-control   # answer y to "Enable Remote Control" and to trusting /projects, then Ctrl+C
   ```

4. Restart the container. From then on it starts the Remote Control server by itself, and the
   session appears in the Claude app.

## Updating

- **Claude Code**: automatic. Restart the container to switch to a downloaded update immediately.
- **Image**: Unraid's Docker tab shows "update ready" after the weekly rebuild; click Apply update.
