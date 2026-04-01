#!/bin/bash
# postCreateCommand -- runs automatically when creating the Dev Container.
# Deps are already pre-installed in the Dockerfile (layer cached).
# Here we only do editable install (src layout) and shift-left validation.
set -euo pipefail

# Fix ownership -- project created as root in WSL, container runs as vscode
sudo chown -R "$(id -u):$(id -g)" .

# Sync deps -- skip if requirements hash matches the Docker build.
# Eliminates ~30s of "Requirement already satisfied" on the happy path.
_deps_hash() { cat requirements.txt requirements-dev.txt 2>/dev/null | sha256sum | cut -d' ' -f1; }
if [ "$(_deps_hash)" = "$(cat /opt/venv/.deps-hash 2>/dev/null)" ]; then
  echo "==> Dependencies already synced (cache hit) ✔"
else
  echo "==> Syncing dependencies..."
  pip install -q -r requirements.txt -r requirements-dev.txt
  _deps_hash > /opt/venv/.deps-hash 2>/dev/null || true
fi

# Editable install (required for src-layout -- imports via package name)
if [ -d src ]; then
  echo "==> Installing package in editable mode (src layout)..."
  pip install -q -e . --no-deps
fi

# Update bash hashmap to find newly-installed executables
hash -r

# Shift-left: validates lint and tests right at setup.
# If it fails here, the dev knows immediately that something is wrong.
# NOTE: || echo ... ensures the container is created even with warnings.
# Lint/test failures should not block setup -- only alert.
echo "==> Checking lint (ruff)..."
ruff check . --quiet || echo -e "\033[0;31m⚠ Lint warnings found -- run 'ruff check .' for details\033[0m"

echo "==> Running tests (pytest)..."
pytest --quiet -m "not integration and not smoke" || echo -e "\033[0;31m⚠ Tests failed -- run 'pytest -v' for details\033[0m"

echo "==> Environment ready ✔"
