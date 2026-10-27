# Always-on Claude Code for Unraid, driven from the Claude app through Remote Control.
#
# Claude Code itself is not baked in. start.sh installs it with Anthropic's official installer into
# the persisted home on first start, and Claude Code's own auto-updater keeps it current from then on.
# This image only carries the OS and tools, and is rebuilt weekly by CI for security updates.

# Floating tag on purpose: the weekly rebuild picks up Debian and Node security fixes.
FROM docker.io/library/node:24-bookworm-slim

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates curl git openssh-client tmux tini jq ripgrep less procps \
      python3 python3-venv tzdata \
      iputils-ping dnsutils netcat-openbsd iproute2 traceroute nmap mosquitto-clients ffmpeg \
      libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# Debian gives ping the cap_net_raw file capability, which the container's --cap-drop ALL and
# no-new-privileges refuse to exec ("Operation not permitted"). Without it, ping uses unprivileged
# ICMP sockets, which Docker allows (net.ipv4.ping_group_range covers every group).
RUN setcap -r /usr/bin/ping

# GitHub CLI from GitHub's own apt repository (Debian's gh is far behind). Sign in once with
# `gh auth login`; the login is kept in the persisted home.
RUN curl -fsSL --proto '=https' -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
      https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# uv, for Python scripts with inline dependencies (vault.py and friends).
COPY --from=ghcr.io/astral-sh/uv:0.12.19 /uv /uvx /usr/local/bin/

# supercronic runs scheduled headless Claude jobs as the non-root user. Pinned and checksum-verified.
ARG SUPERCRONIC_VERSION=0.2.49
ARG SUPERCRONIC_SHA256=a53ae236602c7338aba3fbaff40bda6300eae3b9fedb8261eb06cfe3724430c1
RUN curl -fsSL --proto '=https' -o /usr/local/bin/supercronic \
      "https://github.com/aptible/supercronic/releases/download/v${SUPERCRONIC_VERSION}/supercronic-linux-amd64" \
    && echo "${SUPERCRONIC_SHA256}  /usr/local/bin/supercronic" | sha256sum -c - \
    && chmod 755 /usr/local/bin/supercronic

COPY --chmod=755 start.sh chat-sessions /usr/local/bin/

# An account for Unraid's 99:100 (gid 100 is Debian's "users"); ssh and git refuse to run for a uid
# with no passwd entry.
RUN useradd --uid 99 --gid 100 --home-dir /home/claude --no-create-home --shell /bin/bash claude

# Persisted home (login, settings, CLAUDE.md, skills, scripts, Claude Code itself) and the working folder.
ENV HOME=/home/claude \
    PATH=/home/claude/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TERM=xterm-256color \
    LANG=C.UTF-8
WORKDIR /projects

# Unraid's nobody:users. Override with --user if the appdata folders are owned by someone else.
USER 99:100

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/usr/local/bin/start.sh"]
