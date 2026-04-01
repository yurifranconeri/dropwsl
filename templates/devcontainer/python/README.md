# my-project

> Brief project description.

## Requirements

- Python 3.12+
- [VS Code](https://code.visualstudio.com/) + [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

## Setup (Dev Container)

1. Open the folder in VS Code
2. Accept "Reopen in Container" (or `Ctrl+Shift+P` → `Dev Containers: Reopen in Container`)
3. The container installs everything automatically (venv, dependencies, extensions)

## Usage

```bash
python main.py
```

## Tests

```bash
# Run tests
pytest

# With coverage
pytest --cov

# HTML coverage report (opens htmlcov/index.html)
pytest --cov --cov-report=html
```

## Lint & Format

```bash
# Check for issues
ruff check .

# Auto-fix
ruff check . --fix

# Format code
ruff format .
```

> Ruff auto-formats on save in VS Code (configured in the Dev Container).

## Docker (Production)

```bash
# Build image
docker build -t my-project .

# Build with OCI labels (CI/CD)
docker build \
  --build-arg VERSION=1.0.0 \
  --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t my-project .

# Run
docker run -p 8000:8000 my-project
```

> The production image uses multi-stage build (no pip/setuptools), runs as
> non-root user and includes HEALTHCHECK. Adjust port and route for your app.

## Environment Variables

Copy `.env.example` to `.env` and fill in the values:

```bash
cp .env.example .env
```

> `.env` is in `.gitignore` -- never commit secrets.

## Project Structure

```
.
├── .devcontainer/        # Dev Container config
│   ├── Dockerfile        # Development image
│   ├── devcontainer.json # Extensions, settings, postCreate
│   └── post-create.sh    # Automatic setup (deps, lint, tests)
├── tests/                # Tests (pytest)
│   ├── __init__.py       # Package marker
│   ├── conftest.py       # Shared fixtures
│   └── test_main.py      # Example tests
├── .editorconfig         # Universal formatting (indent, EOL)
├── .env.example          # Environment variables (template)
├── .gitattributes        # Line endings (LF)
├── .gitignore            # Files ignored by Git
├── .dockerignore         # Files ignored by Docker
├── Dockerfile            # Production image
├── main.py               # Entry point
├── pyproject.toml        # Centralized config (ruff, pytest, coverage)
├── requirements.txt      # Production dependencies
├── requirements-dev.txt  # Development dependencies (pytest, ruff)
└── DECISIONS.md          # Technical decisions for this template (can be removed)
```
