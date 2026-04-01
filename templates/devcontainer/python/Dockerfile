# syntax=docker/dockerfile:1
# Update the Python version as needed (e.g. 3.13, 3.14)

# ---- Builder: install dependencies in isolated venv ----
FROM python:3.12-slim-bookworm AS builder

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# pip.conf: generous timeout for large downloads on WSL/VPN networks
COPY pip.conf /etc/pip.conf

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y pip setuptools

# ---- Runtime: lightweight final image ----
FROM python:3.12-slim-bookworm

# OCI labels -- traceability in registry, CI/CD and vulnerability scanning.
# Values injected via: docker build --build-arg VERSION=1.2.3 ...
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG VERSION=0.1.0
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source=""

# Do not generate .pyc (avoids writes on read-only filesystem)
ENV PYTHONDONTWRITEBYTECODE=1
# stdout/stderr unbuffered -- logs appear immediately in Docker
ENV PYTHONUNBUFFERED=1

# Non-root user for production security
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

# Copy venv from builder (pip/setuptools removed in builder stage)
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

COPY --chown=appuser:appuser . .

# Default port -- uncomment and adjust for your framework (e.g. FastAPI/Uvicorn uses 8000)
# The fastapi layer activates this automatically.
# EXPOSE 8000

# HEALTHCHECK allows Docker to detect unhealthy containers.
# IMPORTANT: uncomment and adjust the port and route for your app (e.g. /health, /healthz).
# If the app does not respond on this route, Docker will restart the container in a loop.
# HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
#   CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/')" || exit 1

USER appuser
# exec form: PID 1 = python, recebe SIGTERM diretamente do Docker.
CMD ["python", "main.py"]
