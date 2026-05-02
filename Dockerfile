# syntax=docker/dockerfile:1.7

# Personal devcontainer base image: Ubuntu + Rust + Node + gh + Claude Code +
# cargo dev tools, all installed at build time so downstream devcontainers
# spend `devpod up` time pulling one image instead of compiling from source
# inside an underpowered laptop sandbox.
#
# Built and published by GitHub Actions to ghcr.io. Downstream:
#   FROM ghcr.io/<owner>/devcontainer-base-image:latest
# Or pin by digest for reproducibility.

ARG UBUNTU_VARIANT=ubuntu-24.04
FROM mcr.microsoft.com/devcontainers/base:${UBUNTU_VARIANT}

# Re-declare ARGs after FROM so they're available in subsequent layers
ARG NODE_VERSION=20
ARG NVM_VERSION=v0.40.1
ARG RUST_DEFAULT_TOOLCHAIN=stable
ARG CARGO_INSTALL_TOOLS="cargo-llvm-cov cargo-edit"

# 1. System packages: build deps for native-rs / cargo, plus a usable shell.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential pkg-config libssl-dev \
        git curl ca-certificates gnupg \
        zsh fzf less jq \
    && rm -rf /var/lib/apt/lists/*

# 2. GitHub CLI from the official apt repo (small, signed).
RUN install -dm 0755 /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
         | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
         > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# 3. Rust toolchain (rustup + default toolchain + common components).
#    Installed system-wide under /usr/local so non-vscode users (or non-default
#    UIDs from devcontainer remoteUser overrides) still find it.
ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --default-toolchain "${RUST_DEFAULT_TOOLCHAIN}" \
            --component clippy --component rustfmt --component llvm-tools-preview \
    && chmod -R a+rX "${CARGO_HOME}" "${RUSTUP_HOME}"

# 4. Cargo dev tools — the slow step. Compiled from source on the GHA runner
#    once per image build, baked into /usr/local/cargo/bin so downstream
#    devcontainers don't pay the compile cost on every `devpod up`.
RUN cargo install --locked ${CARGO_INSTALL_TOOLS} \
    && chmod -R a+rX "${CARGO_HOME}"

# 5. Node via nvm, installed system-wide so PATH-on-shell sees it.
ENV NVM_DIR=/usr/local/share/nvm
RUN mkdir -p "${NVM_DIR}" \
    && curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" \
         | PROFILE=/dev/null bash \
    && . "${NVM_DIR}/nvm.sh" \
    && nvm install "${NODE_VERSION}" \
    && nvm alias default "${NODE_VERSION}" \
    && ln -sfn "${NVM_DIR}/versions/node/$(nvm version default)" "${NVM_DIR}/current" \
    && chmod -R a+rX "${NVM_DIR}"
ENV PATH=${NVM_DIR}/current/bin:${PATH}

# 6. Claude Code CLI via the official installer.
#    Run as the vscode user so the binary lands under /home/vscode/.local/bin
#    (matches the runtime layout downstream devcontainers expect).
USER vscode
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && test -x /home/vscode/.local/bin/claude
ENV PATH=/home/vscode/.local/bin:${PATH}

# 7. PATH hint for interactive shells (login + non-login).
USER root
RUN printf 'export PATH="/home/vscode/.local/bin:%s/current/bin:/usr/local/cargo/bin:$PATH"\n' "${NVM_DIR}" \
        > /etc/profile.d/devbase-path.sh \
    && chmod 0644 /etc/profile.d/devbase-path.sh

# 8. Final: drop back to vscode user, set workdir.
USER vscode
WORKDIR /workspace

# Image labels (also overridden by the GHA workflow with metadata-action).
LABEL org.opencontainers.image.source="https://github.com/yumike/devcontainer-base-image"
LABEL org.opencontainers.image.description="Personal devcontainer base: Ubuntu 24.04 + Rust + Node + gh + Claude Code"
LABEL org.opencontainers.image.licenses="MIT"
