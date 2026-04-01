# Development image -- same Python version as production (3.12).
# Full base (bookworm) for debug/troubleshooting; prod uses slim-bookworm.
FROM python:3.12-bookworm

# Non-root user + Docker CLI + GitHub CLI in a single cacheable layer.
# Replaces the Dev Container Features (docker-outside-of-docker, github-cli)
# which ran separate installs without cache -- ~5min each rebuild.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m --shell /bin/bash $USERNAME \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        sudo ca-certificates curl gnupg \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    # Docker CLI (socket montado do host via devcontainer.json)
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list \
    # GitHub CLI
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /etc/apt/keyrings/githubcli.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli.gpg] \
        https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        docker-ce-cli docker-buildx-plugin docker-compose-plugin gh \
    && rm -rf /var/lib/apt/lists/* \
    # Docker group -- allows using docker without sudo
    && groupadd -f docker \
    && usermod -aG docker $USERNAME \
    && mkdir -p /home/$USERNAME/.cache \
    && chown -R $USERNAME:$USERNAME /home/$USERNAME/.cache

# Venv at fixed path -- works in any project, any terminal,
# docker exec, CI, etc. Does not depend on VS Code interpolation.
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:${PATH}"

# pip.conf: generous timeout for large downloads on WSL/VPN networks
COPY pip.conf /etc/pip.conf

# Activate venv in .bashrc so the prompt shows (venv)
RUN python -m venv $VIRTUAL_ENV \
    && chown -R $USERNAME:$USERNAME $VIRTUAL_ENV \
    && echo '. /opt/venv/bin/activate' >> /home/$USERNAME/.bashrc

# Pre-install deps at build time -- cached until requirements change.
# --mount=type=cache: pip reuses downloads across builds (even with new deps).
# .deps-hash: allows post-create.sh to skip pip install if deps haven't changed.
COPY requirements.txt requirements-dev.txt /tmp/pip-reqs/
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install \
        -r /tmp/pip-reqs/requirements-dev.txt \
        -r /tmp/pip-reqs/requirements.txt \
    && cat /tmp/pip-reqs/requirements.txt /tmp/pip-reqs/requirements-dev.txt \
        | sha256sum | cut -d' ' -f1 > /opt/venv/.deps-hash \
    && rm -rf /tmp/pip-reqs
