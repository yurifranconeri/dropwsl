"""CLI inspector for the Settings class.

Subcommands:
    show       Print current settings (secrets masked).
    validate   Load Settings() and exit 0 on success, 1 on validation error.
    dump-env   Emit a .env template derived from the Settings fields.
    schema     Print the JSON schema of Settings.
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

from pydantic import SecretStr, ValidationError

from {{PKG_PREFIX}}config.settings import Settings, get_settings

PROG = "python -m {{PKG_PREFIX}}config"


def _mask_secrets(data: dict[str, Any]) -> dict[str, Any]:
    """Replace SecretStr values with `***` for safe display."""
    masked: dict[str, Any] = {}
    for key, value in data.items():
        if isinstance(value, SecretStr):
            masked[key] = "***" if value.get_secret_value() else ""
        elif isinstance(value, dict):
            masked[key] = _mask_secrets(value)
        else:
            masked[key] = value
    return masked


def cmd_show(_args: argparse.Namespace) -> int:
    get_settings.cache_clear()
    try:
        settings = get_settings()
    except ValidationError as exc:
        print(f"Configuration error:\n{exc}", file=sys.stderr)
        return 1
    payload = _mask_secrets(settings.model_dump())
    print(json.dumps(payload, indent=2, default=str, sort_keys=True))
    return 0


def cmd_validate(_args: argparse.Namespace) -> int:
    get_settings.cache_clear()
    try:
        get_settings()
    except ValidationError as exc:
        print(f"Configuration invalid:\n{exc}", file=sys.stderr)
        return 1
    print("Configuration valid.")
    return 0


def cmd_schema(_args: argparse.Namespace) -> int:
    print(json.dumps(Settings.model_json_schema(), indent=2, sort_keys=True))
    return 0


def cmd_dump_env(_args: argparse.Namespace) -> int:
    """Emit a .env template from Settings fields with defaults as placeholders."""
    lines: list[str] = ["# Generated from Settings class fields"]
    for field_name, field_info in Settings.model_fields.items():
        env_name = field_name.upper()
        description = (field_info.description or "").strip()
        if description:
            lines.append(f"# {description}")
        default = field_info.default
        if default is None or repr(default).startswith("PydanticUndefined"):
            lines.append(f"{env_name}=")
        else:
            lines.append(f"{env_name}={default}")
        lines.append("")
    print("\n".join(lines).rstrip() + "\n", end="")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog=PROG,
        description="Inspect and validate application settings.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("show", help="Print current settings (secrets masked).")
    sub.add_parser("validate", help="Validate settings; exit non-zero on error.")
    sub.add_parser("dump-env", help="Emit a .env template from Settings fields.")
    sub.add_parser("schema", help="Print the JSON schema of Settings.")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    handlers = {
        "show": cmd_show,
        "validate": cmd_validate,
        "dump-env": cmd_dump_env,
        "schema": cmd_schema,
    }
    return handlers[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())
