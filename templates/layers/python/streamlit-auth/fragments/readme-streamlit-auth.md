## Authentication

Form-based authentication via `streamlit-authenticator`. Credentials stored
in `users_data/credentials.yaml` with bcrypt hashes; cookie HMAC key in
`.env`. Storage is abstracted via a `CredentialStore` Protocol — `YamlStore`
is the default; swap for a DB-backed store later without changing app code.

### Bootstrap (3 steps)

```bash
# 1. Seed credentials file from template
cp users_data/credentials.example.yaml users_data/credentials.yaml

# 2. Generate a strong cookie key (writes to .env)
python -m {{PKG_PREFIX}}users gen-cookie-key

# 3. Add the first user (prompts for name, email, password, optional role)
python -m {{PKG_PREFIX}}users add alice
```

### Wire-up in `main.py` (2 lines)

```python
from {{PKG_PREFIX}}users import require_login

user = require_login()                                  # blocks render if not logged in
st.sidebar.write(f"Logged in as {user['name']}")
```

To gate by role:

```python
user = require_login(required_role="admin")             # 403-style block if role mismatch
```

### CLI reference

```bash
python -m {{PKG_PREFIX}}users list                      # list users (no hashes)
python -m {{PKG_PREFIX}}users add <username>            # interactive add
python -m {{PKG_PREFIX}}users passwd <username>         # change password
python -m {{PKG_PREFIX}}users remove <username>         # delete user
python -m {{PKG_PREFIX}}users gen-cookie-key            # generate + persist cookie key
python -m {{PKG_PREFIX}}users verify <username>         # verify password (exit 0/1)
```

### Deploying to cloud (checklist)

- `AUTH_COOKIE_KEY` must come from a secret manager (Azure Key Vault, AWS
  Secrets Manager, Fly secrets). Never bake into the image.
- `users_data/credentials.yaml` is gitignored AND dockerignored. Mount it as
  a secret volume in single-replica deployments, or migrate to a DB-backed
  store for multi-replica.
- TLS is the provider's responsibility (Container Apps, App Service,
  Cloudflare). Cookie HMAC alone does not protect transport.
- For multi-replica scale, replace `YamlStore` with a DB-backed
  `CredentialStore` implementation — `gate.py` and `cli.py` will keep working.

See `users_data/README.md` for a more detailed runbook.
