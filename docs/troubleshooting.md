# Troubleshooting

## `WSL_E_DISTRO_NOT_FOUND` when opening the distro after install

```
There is no distribution with the supplied name.
Error code: Wsl/Service/CreateInstance/ReadDistroConfig/WSL_E_DISTRO_NOT_FOUND
```

**Cause:** The terminal was opened before `wsl --install` finished registering the distro.

**Fix:** Close and reopen the terminal. If it persists, restart Windows.

---

## Dev Container fails with `NO_PUBKEY` (Yarn GPG)

```
E: The repository 'https://dl.yarnpkg.com/debian stable InRelease' is not signed.
ERROR: Feature "Docker (docker-outside-of-docker)" failed to install!
```

**Cause:** The `mcr.microsoft.com/devcontainers/python` image includes Node.js + Yarn with an expired GPG key. The current template uses `python:3.12-bookworm` (official Docker image, no Node/Yarn), avoiding this issue.

**Fix:** This only applies to projects generated from the old MCR-based template. Regenerate the Dev Container files for that existing project:

```bash
dropwsl scaffold python -y
```

If the project was created with the current template, this migration is not needed.

---

## `bash\r: No such file or directory`

The file has Windows line endings (CRLF).

**Cause:** Your local Git may be overwriting with `core.autocrlf = true`.

**Fix:** `install.ps1` already converts CRLF to LF automatically. If the problem occurs after installation, re-run:

```powershell
.\install.cmd
```

> The repository includes `.gitattributes` to enforce LF. Also fix your global Git setting:
>
> ```bash
> git config --global core.autocrlf input
> ```

---

## Docker daemon not responding after installation

```
FAIL - docker daemon not responding
```

**Cause:** The `docker` group was added to the user but the current session doesn't recognize it.

**Fix:** Close **all** WSL sessions (including VS Code integrated terminals) and reopen:

```powershell
wsl --shutdown
wsl -d Ubuntu-24.04
```

If it persists, re-run the installation:

```powershell
.\install.cmd
```

---

## systemd not active after restarting WSL

```
FAIL - systemd not active
```

**Cause:** `install.ps1` configures systemd automatically in `/etc/wsl.conf`. WSL needs to restart to apply the change.

**Fix:** Re-run the installation — it performs shutdown and restart automatically:

```powershell
.\install.cmd
```

If the problem persists, run the diagnostics:

```powershell
dropwsl doctor
```

---

## Docker Compose not found

```
docker: 'compose' is not a docker command.
```

**Cause:** Docker Compose v2 was not installed or the plugin is not in the path.

**Fix:** Re-run dropwsl to install the plugin:

```powershell
dropwsl install
```

---

## kind cluster fails to create

```
ERROR: failed to create cluster: ...
```

**Cause:** Docker daemon may not be running, or there is insufficient memory/disk.

**Fix:**

1. Verify Docker is running: `docker info`
2. Check available memory: `free -h`
3. Run diagnostics for detailed causes:

```powershell
dropwsl doctor
```

---

## Azure CLI login fails

```
AADSTS... error
```

**Cause:** Expired credentials or incorrect tenant.

**Fix:**

```bash
az login --tenant <TENANT_ID>
```

---

## Command not found after installation

```
kubectl: command not found
```

**Cause:** PATH doesn't include the tool's directory, or the WSL session needs to be reopened.

**Fix:** Close and reopen WSL. If it persists:

```bash
dropwsl validate
```

---

## Automatic diagnostics with `doctor`

For a full diagnostic with probable causes and fixes:

```powershell
dropwsl doctor
```

`doctor` checks every installed component and suggests specific fixes when it detects problems.

---

## `dropwsl: command not found`

**Cause:** PATH doesn't include the dropwsl directory or the symlink was not created during installation.

**Fix:** Re-run the installation:

```powershell
.\install.cmd
```

---

## Permission denied on Docker socket

```
permission denied while trying to connect to the Docker daemon socket
```

**Cause:** User is not in the `docker` group or the WSL session doesn't recognize the group.

**Fix:** Re-run the installation and reopen the terminal:

```powershell
.\install.cmd
```

After it finishes, close and reopen WSL for the group to take effect.
