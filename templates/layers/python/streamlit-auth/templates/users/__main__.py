"""CLI entry point: `python -m {{PKG_PREFIX}}users <command>`."""

from .cli import main

if __name__ == "__main__":
    raise SystemExit(main())
