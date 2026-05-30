# users_data/

This directory holds the credentials file for the `streamlit-auth` layer.

## Files

| File | Tracked in Git | Purpose |
|------|----------------|---------|
| `credentials.example.yaml` | yes | Template with placeholder users — never edit with real hashes |
| `credentials.yaml`         | **no** (gitignored + dockerignored) | Live credentials with bcrypt hashes |
| `README.md`                | yes | This file |

## Quickstart

```bash
cp users_data/credentials.example.yaml users_data/credentials.yaml
python -m {{PKG_PREFIX}}users gen-cookie-key     # writes AUTH_COOKIE_KEY to .env
python -m {{PKG_PREFIX}}users add alice          # prompts for name, email, password, role
python -m {{PKG_PREFIX}}users list               # confirm
```

## Security checklist

- [ ] `users_data/credentials.yaml` is **not** committed (`git status` shows nothing)
- [ ] `AUTH_COOKIE_KEY` in `.env` is a fresh value from `gen-cookie-key` (32+ chars)
- [ ] `.env` is **not** committed
- [ ] In production: `credentials.yaml` lives on a private volume or is
      replaced by a DB-backed `CredentialStore`
- [ ] In production: `AUTH_COOKIE_KEY` comes from a secret manager
      (Azure Key Vault, AWS Secrets Manager, Fly secrets), not a checked-in
      env file
- [ ] Backup strategy in place if using `YamlStore` (the file is the source
      of truth)

## Storage migration (file → DB)

When you outgrow `YamlStore` (multi-replica deployment, audit logging, etc.),
implement the `CredentialStore` Protocol in your own module:

```python
from {{PKG_PREFIX}}users.store import CredentialStore, User

class PostgresStore:
    def get(self, username: str) -> User | None: ...
    def list(self) -> list[User]: ...
    def upsert(self, user: User) -> None: ...
    def delete(self, username: str) -> bool: ...
    def verify(self, username: str, password: str) -> bool: ...
```

Then pass it into `require_login`:

```python
from {{PKG_PREFIX}}users import require_login
from myapp.stores import PostgresStore

user = require_login(store=PostgresStore())
```

`gate.py` and `cli.py` do not need to change.
