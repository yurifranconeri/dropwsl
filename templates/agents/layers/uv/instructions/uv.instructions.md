---
applyTo: "**/requirements*.txt,**/pyproject.toml,**/Dockerfile"
---

# uv Rules

- This project uses uv instead of pip for dependency management
- Install deps: `uv pip install -r requirements.txt` (not `pip install`)
- Add a dependency: add to `requirements.txt` then run `uv pip install -r requirements.txt`
- uv is faster than pip (10-100x) — do not install pip or use pip commands
- In Dockerfile: `RUN uv pip install --no-cache ...` (uv is already in the image)
