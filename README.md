# devcontainer-base-image

Personal prebuilt devcontainer base image. Heavy tooling is installed at
GitHub Actions build time and pulled as one image at `devpod up` time, so
laptop iterations don't pay for re-compiling rust dev tools, re-resolving
nvm, or re-downloading Claude Code on every container creation.

What's baked in:

- Ubuntu 24.04 (`mcr.microsoft.com/devcontainers/base:ubuntu-24.04`)
- Build deps (`build-essential`, `pkg-config`, `libssl-dev`)
- `git`, `curl`, `gnupg`, `zsh`, `fzf`, `less`, `jq`, `tmux`
- GitHub CLI (`gh`)
- Rust toolchain via rustup (default `stable` + `clippy`, `rustfmt`,
  `llvm-tools-preview`)
- `cargo-llvm-cov`, `cargo-edit` (compiled at build time, cached in image)
- Node (Active LTS) via nvm (system-wide at `/usr/local/share/nvm`)
- Claude Code CLI at `/home/vscode/.local/bin/claude`

Default user is `vscode` (provided by the Microsoft base image, with
passwordless sudo). Workdir is `/workspace`.

## Image refs

Published to `ghcr.io/yumike/devcontainer-base-image` on every push to
`main` and weekly via cron. Tags:

- `latest` — head of `main`. Floating; do not pin builds to this in
  production-ish setups.
- `YYYY-MM-DD` — date stamp at build time. Human-readable; mutable within
  the day (the last build of the day wins).
- `<short-sha>` — short git SHA, immutable.
- `@sha256:...` — content-addressable digest, fully immutable. Use this
  for downstream `FROM` if you want bit-reproducibility.

Multi-arch: `linux/amd64` + `linux/arm64`.

## Downstream usage

```Dockerfile
# Floating tag (auto-bumps weekly)
FROM ghcr.io/yumike/devcontainer-base-image:latest

# Or pin by digest (immutable)
FROM ghcr.io/yumike/devcontainer-base-image@sha256:<digest>
```

If your downstream devcontainer mounts a named volume on `/usr/local/cargo`
to persist the cargo target/registry cache, the volume will shadow the
baked-in `cargo-llvm-cov` / `cargo-edit` binaries on first container start.
Either:

- Mount only the cache subdirs (`/usr/local/cargo/registry`,
  `/usr/local/cargo/git`) — recommended; preserves baked-in `cargo-*`
  binaries.
- Or accept that downstream will need to `cargo install` those again on
  first run.

## Build args

Override via `--build-arg`:

| Arg | Default | Notes |
| --- | --- | --- |
| `UBUNTU_VARIANT` | `ubuntu-24.04` | Microsoft base image tag |
| `NODE_VERSION` | Active LTS (Renovate-tracked) | nvm install target |
| `NVM_VERSION` | Renovate-tracked | nvm itself |
| `RUST_DEFAULT_TOOLCHAIN` | `stable` | rustup default |
| `CARGO_INSTALL_TOOLS` | `cargo-llvm-cov cargo-edit` | space-separated cargo crates |

## Local build (sanity check)

```bash
docker buildx build --platform linux/arm64 -t devcontainer-base-image:dev .
```

QEMU multi-arch is configured in CI; locally, build for your native
platform only unless you have buildx + qemu set up.
