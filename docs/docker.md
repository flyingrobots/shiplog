# Docker & Dev Container Strategy

Shiplog intentionally performs aggressive Git operations (force-updating hidden refs, generating throw-away remotes, etc.). Running those flows directly inside this repository is dangerous and can corrupt your checkout. **Always exercise Shiplog commands inside one of the provided containers or a disposable sandbox repo. Do not run `git shiplog` in this repo on your host.**

## Images at a Glance

We publish a single multi-stage `Dockerfile` at the repo root. It uses Ubuntu 24.04 as the common base image and exposes two stages:

- `test` (default) – copies the repository into `/workspace`, provisions the throw-away test harness, and exposes `/usr/local/bin/run-tests`. CI and local test runs should target this stage.
- `devcontainer` – minimal tooling layer for Codespaces/VS Code. It inherits the same package set but does not copy the repository. The `.devcontainer/devcontainer.json` file builds this stage and mounts the repo at `/workspaces/shiplog` at runtime.

Because both stages share the `base` layer, we only install Git, jq, bats, shellcheck, etc. once. Anyone consuming either image benefits from the same toolchain and versions (Git 2.43, jq 1.7.1, Bats 1.10, etc.).

## Using the Dev Container

1. Open the repository in VS Code (local or Codespaces).
2. When prompted, reopen in container—or run `Dev Containers: Reopen in Container`.
3. The editor will build the `devcontainer` stage and mount the repository at `/workspaces/shiplog`.
4. Work inside the container shell. If you need the image locally, run:
   ```bash
   docker build --target devcontainer -t shiplog-dev .
   docker run --rm -it -v "$PWD":/workspaces/shiplog shiplog-dev
   ```

**Again: avoid running `git shiplog …` inside this repo on your host.** Use the mounted workspace or a sandbox clone when you need to exercise the CLI.

## Running Tests

- `make test` builds the `test` stage and executes the Bats suite. The image now bakes in the repository snapshot (no bind mount) before copying it into an ephemeral directory, spinning up a throw-away Git repo, and running `bats -r test` in isolation.
- The CI matrix reuses a single `ci-matrix/Dockerfile`. `docker-compose.yml` builds that file five times with different `BASE_IMAGE`/`DISTRO_FAMILY` values (Debian bookworm, Ubuntu 24.04, Fedora 40, Alpine 3.20, Arch). All of them share the same package install logic and the same `/usr/local/bin/run-tests` script; only the base layer differs.
- To exercise the matrix locally:
  ```bash
  pushd ci-matrix
  docker compose build
  docker compose run --rm debian
  docker compose run --rm ubuntu
  # …and so on for fedora, alpine, arch
  popd
  ```

## Local Sandbox Workflow

If you need to run Shiplog commands manually, clone a disposable repo or use the test sandbox (`shiplog-sandbox.sh`). Never operate against this repository’s Git checkout on your host; let the containers set up isolated remotes for you.
