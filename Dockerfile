# syntax=docker/dockerfile:1

FROM archlinux:base-devel

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    TZ=America/Los_Angeles \
    PATH="/root/.local/bin:/root/.bun/bin:/root/go/bin:/root/.cargo/bin:/opt/java/bin:${PATH}" \
    JAVA_HOME="/opt/java" \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    BUN_INSTALL="/root/.bun"

RUN --mount=type=cache,target=/var/cache/pacman/pkg,sharing=locked \
    pacman -Syu --noconfirm --needed \
        tzdata curl wget git unzip zip  \
        jq go-yq ripgrep fd tree \
        openssh \
        python python-pip uv \
        nodejs npm \
        go

# Configure timezone
RUN ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime

# ---------------- AI Agent ----------------

ENV DO_NOT_TRACK=1 \
    OTEL_SDK_DISABLED=true \
    DISABLE_AUTOUPDATER=1 \
    CODEX_NON_INTERACTIVE=1 \
    START_T3CODE=true \
    T3CODE_HOST=0.0.0.0 \
    T3CODE_PORT=3773 \
    T3CODE_TELEMETRY_ENABLE=false \
    T3CODE_OTEL_SDK_DISABLED=true \
    CTX7_TELEMETRY_DISABLED=1 \
    RTK_TELEMETRY_DISABLED=1 \
    CAVEMAN_TELEMETRY=0 \
    CODEGRAPH_TELEMETRY=0 \
    SERENA_USAGE_REPORTING=false

# Install Codex
RUN --mount=type=cache,target=/root/.npm \
    npm install -g @openai/codex@latest \
    && codex --version

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && claude --version

# Install Bun and Oh My Pi
RUN --mount=type=cache,target=/root/.bun/install/cache \
    curl -fsSL https://bun.sh/install | bash \
    && bun --version \
    && bun install -g @oh-my-pi/pi-coding-agent@latest \
    && omp --version

# Install T3 Code
RUN curl -fsSL https://t3.codes/install.sh | sh \
    && t3 --version

# Install agent configurations
RUN --mount=type=bind,source=config,target=/tmp/config \
    install -Dm644 /tmp/config/codex.toml /root/.codex/config.toml \
    && install -Dm644 /tmp/config/AGENTS.md /root/.codex/AGENTS.md \
    && install -Dm644 /tmp/config/claude.json /root/.claude/settings.json \
    && install -Dm644 /tmp/config/AGENTS.md /root/.claude/CLAUDE.md \
    && install -Dm644 /tmp/config/omp-config.yml /root/.omp/agent/config.yml \
    && install -Dm644 /tmp/config/omp-models.yml /root/.omp/agent/models.yml \
    && install -Dm644 /tmp/config/AGENTS.md /root/.omp/agent/AGENTS.md \
    && install -Dm644 /tmp/config/t3.json /root/.config/foxos/t3.json

# Install integrations at build time without stdin.
# https://context7.com/docs/clients/cli CLI + Skill
RUN --mount=type=cache,target=/root/.npm \
    npm install -g ctx7@latest \
    && npx -y skills add upstash/context7 --skill find-docs \
        --agent codex claude-code --global --yes </dev/null

# https://exa.ai/docs/get-started/agent-skills/overview Skill
RUN --mount=type=cache,target=/root/.npm \
    npx -y skills add exa-labs/agent-skills --skill exa-search exa-contents \
        --agent codex claude-code --global --yes </dev/null

# http://github.com/DietrichGebert/ponytail/blob/main/INSTALL.md Plugin
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/root/.bun/install/cache \
    codex plugin marketplace add DietrichGebert/ponytail </dev/null \
    && codex plugin add ponytail@ponytail </dev/null \
    && claude plugin marketplace add DietrichGebert/ponytail </dev/null \
    && claude plugin install ponytail@ponytail </dev/null \
    && omp plugin marketplace add DietrichGebert/ponytail </dev/null \
    && omp plugin install ponytail@ponytail </dev/null

# https://www.rtk-ai.app/docs/getting-started/installation/ AGENTS.md + Hook
RUN curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh \
    && rtk init -g --codex </dev/null \
    && rtk init -g --auto-patch </dev/null \
    && rtk init -g --agent omp --auto-patch </dev/null

# https://github.com/JuliusBrussee/caveman/blob/main/INSTALL.md Skill (Codex) / Plugin (Claude + OMP)
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/root/.bun/install/cache \
    npx --allow-git=root -y github:JuliusBrussee/caveman -- --only codex --non-interactive </dev/null \
    && claude plugin marketplace add JuliusBrussee/caveman </dev/null \
    && claude plugin install caveman@caveman </dev/null \
    && npx --allow-git=root -y github:JuliusBrussee/caveman -- --only omp --non-interactive </dev/null

# https://oraios.github.io/serena/02-usage/010_installation.html MCP
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/root/go/pkg/mod \
    --mount=type=cache,target=/root/.npm \
    UV_LINK_MODE=copy uv tool install -p 3.13 serena-agent \
    && serena init </dev/null \
    && go install golang.org/x/tools/gopls@latest \
    && serena download-ls-dependencies typescript </dev/null \
    && serena setup codex </dev/null \
    && serena setup claude-code </dev/null

# Entrypoint
COPY --chmod=755 config.sh /usr/local/bin/foxos-config.sh
COPY --chmod=755 env/ /usr/local/bin/env/
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

EXPOSE 3773

WORKDIR /root/.t3/projects

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["/bin/bash"]