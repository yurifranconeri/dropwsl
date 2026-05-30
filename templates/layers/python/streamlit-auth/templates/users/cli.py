"""CLI for managing users: `python -m {{PKG_PREFIX}}users <command>`.

Commands:
    list                       List users (no password hashes)
    add <username>             Add a user (interactive)
    passwd <username>          Change a user's password (interactive)
    remove <username>          Delete a user
    gen-cookie-key             Generate a cookie HMAC key and update .env
    verify <username>          Verify a password (exit 0 on success, 1 otherwise)
"""

from __future__ import annotations

import argparse
import getpass
import secrets
import sys
from pathlib import Path

from .store import User, YamlStore, hash_password

PROG = "python -m {{PKG_PREFIX}}users"
ENV_PATH = Path(".env")
COOKIE_KEY_LEN = 32


def _prompt_password(label: str = "Password") -> str:
    pwd = getpass.getpass(f"{label}: ")
    confirm = getpass.getpass(f"{label} (confirm): ")
    if pwd != confirm:
        print("ERROR: passwords do not match.", file=sys.stderr)
        sys.exit(2)
    if len(pwd) < 8:
        print("ERROR: password must be at least 8 characters.", file=sys.stderr)
        sys.exit(2)
    return pwd


def cmd_list(args: argparse.Namespace) -> int:
    store = YamlStore()
    users = store.list()
    if not users:
        print("(no users)")
        return 0
    fmt = "{:<20} {:<30} {:<30} {:<10}"
    print(fmt.format("USERNAME", "NAME", "EMAIL", "ROLE"))
    print(fmt.format("-" * 20, "-" * 30, "-" * 30, "-" * 10))
    for u in users:
        print(
            fmt.format(
                u.get("username", ""),
                u.get("name", ""),
                u.get("email", ""),
                u.get("role", ""),
            )
        )
    return 0


def cmd_add(args: argparse.Namespace) -> int:
    store = YamlStore()
    if store.get(args.username) is not None:
        print(f"ERROR: user '{args.username}' already exists.", file=sys.stderr)
        return 1
    name = args.name or input("Name: ").strip()
    email = args.email or input("Email: ").strip()
    role = args.role if args.role is not None else input("Role (optional): ").strip()
    password = _prompt_password()
    user: User = {
        "username": args.username,
        "name": name,
        "email": email,
        "password_hash": hash_password(password),
    }
    if role:
        user["role"] = role
    store.upsert(user)
    print(f"User '{args.username}' added.")
    return 0


def cmd_passwd(args: argparse.Namespace) -> int:
    store = YamlStore()
    user = store.get(args.username)
    if user is None:
        print(f"ERROR: user '{args.username}' not found.", file=sys.stderr)
        return 1
    password = _prompt_password("New password")
    user["password_hash"] = hash_password(password)
    store.upsert(user)
    print(f"Password updated for '{args.username}'.")
    return 0


def cmd_remove(args: argparse.Namespace) -> int:
    store = YamlStore()
    if not store.delete(args.username):
        print(f"ERROR: user '{args.username}' not found.", file=sys.stderr)
        return 1
    print(f"User '{args.username}' removed.")
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    store = YamlStore()
    password = getpass.getpass("Password: ")
    if store.verify(args.username, password):
        print("OK")
        return 0
    print("FAIL", file=sys.stderr)
    return 1


def cmd_gen_cookie_key(args: argparse.Namespace) -> int:
    key = secrets.token_urlsafe(COOKIE_KEY_LEN)
    # Try to update .env in-place; otherwise print to stdout
    if ENV_PATH.exists():
        lines = ENV_PATH.read_text(encoding="utf-8").splitlines()
        updated = False
        out: list[str] = []
        for line in lines:
            if line.startswith("AUTH_COOKIE_KEY="):
                out.append(f"AUTH_COOKIE_KEY={key}")
                updated = True
            else:
                out.append(line)
        if not updated:
            out.append(f"AUTH_COOKIE_KEY={key}")
        ENV_PATH.write_text("\n".join(out) + "\n", encoding="utf-8")
        print(f"AUTH_COOKIE_KEY updated in {ENV_PATH}")
    else:
        print(f"AUTH_COOKIE_KEY={key}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog=PROG, description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="List users").set_defaults(func=cmd_list)

    p_add = sub.add_parser("add", help="Add a user")
    p_add.add_argument("username")
    p_add.add_argument("--name", default=None)
    p_add.add_argument("--email", default=None)
    p_add.add_argument("--role", default=None)
    p_add.set_defaults(func=cmd_add)

    p_passwd = sub.add_parser("passwd", help="Change a user's password")
    p_passwd.add_argument("username")
    p_passwd.set_defaults(func=cmd_passwd)

    p_remove = sub.add_parser("remove", help="Delete a user")
    p_remove.add_argument("username")
    p_remove.set_defaults(func=cmd_remove)

    p_verify = sub.add_parser("verify", help="Verify a password (exit 0/1)")
    p_verify.add_argument("username")
    p_verify.set_defaults(func=cmd_verify)

    sub.add_parser(
        "gen-cookie-key",
        help="Generate a cookie HMAC key and update .env",
    ).set_defaults(func=cmd_gen_cookie_key)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))
