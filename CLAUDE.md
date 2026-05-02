# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A single-Dockerfile project that publishes a personal devcontainer base image
(`ghcr.io/yumike/devcontainer-base-image`) via GitHub Actions. There is no
application code — the deliverable is the image itself.

Core constraint: **expensive tooling is installed at GHA build time, not at
`devpod up` time.** The whole design exists so downstream devcontainers pull
one prebuilt image instead of recompiling cargo tools or re-resolving nvm on
every container start.

## Common commands

Local sanity build (native arch only — multi-arch is CI's job):

```bash
docker buildx build --platform linux/arm64 -t devcontainer-base-image:dev .
```

Override build args with `--build-arg`, e.g. `--build-arg NODE_VERSION=22`.
See README "Build args" for the full list.

There is no test suite, lint, or formatter — changes are validated by a
successful build (locally or in CI) and by exercising the resulting image.

## Architecture notes that aren't obvious from the Dockerfile

**Layer ordering is load-bearing.** Layers are: system packages → `gh` →
Rust toolchain → `cargo install` (the slow step) → Node/nvm → Claude Code.
Slow/stable layers go before fast/volatile ones so cache hits are maximized.
Don't reorder casually.

**Rust lives at `/usr/local`, not in `$HOME`.** `CARGO_HOME=/usr/local/cargo`
and `RUSTUP_HOME=/usr/local/rustup` are intentional: downstream devcontainers
sometimes override `remoteUser` to a non-default UID, and a HOME-scoped
toolchain wouldn't be visible. Anything you add that should be available to
arbitrary users belongs under `/usr/local`.

**Claude Code is installed AS `vscode`, not root.** It must land in
`/home/vscode/.local/bin/claude` because that's the path downstream configs
expect. Don't move that step to a root layer.

**The cargo-volume-shadowing footgun.** If a downstream devcontainer mounts a
named volume on `/usr/local/cargo`, it shadows the baked-in `cargo-llvm-cov`
/ `cargo-edit` binaries. Mitigation documented in README; preserve the
`/usr/local/cargo/bin` location if you add more cargo tools so the same
mitigation applies.

**`PATH` is set in three places** (`ENV PATH=...` for cargo, `ENV PATH=...`
for nvm current symlink, and `/etc/profile.d/devbase-path.sh` for
interactive login shells). All three are needed: the `ENV` lines cover
non-interactive `docker exec`, the profile.d file covers login shells that
reset PATH. If you add a tool to a new directory, update all three.

## Publishing & tagging

GHA (`.github/workflows/build.yml`) pushes on every `main` commit and weekly
on Monday 06:00 UTC. Weekly cron is what refreshes the apt layer / rustup
channel / nvm — so just letting it tick is the upgrade path for transitive
deps.

Tags emitted: `latest` (mutable, default branch only), `YYYY-MM-DD` (build
day, mutable within the day), short SHA (immutable), and the implicit
content-addressable `@sha256:...`. `provenance: false` is intentional — GHCR
renders provenance manifests as `unknown/unknown` entries; re-enable only
when GHCR supports them cleanly.

The workflow's `paths-ignore` skips builds for README/LICENSE/.gitignore
edits. If you add docs-only files that shouldn't trigger a rebuild, extend
that list.
