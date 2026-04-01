## Docker (Production)

```bash
# Start all services (app + infrastructure)
docker compose --profile prod up --build -d

# View logs
docker compose --profile prod logs -f

# Stop
docker compose --profile prod down
```

> The `app` service uses `profiles: [prod]` -- it only starts with `--profile prod`.
> Without the flag, `docker compose up -d` starts only infrastructure (database, cache).

<details>
<summary>Standalone (without compose)</summary>

```bash
docker build -t {{PROJECT_NAME}} .
docker run -p 8000:8000 {{PROJECT_NAME}}
```

</details>

