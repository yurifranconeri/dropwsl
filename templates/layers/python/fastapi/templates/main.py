"""FastAPI application -- main entry point."""

from fastapi import FastAPI

app = FastAPI(title="{{PROJECT_NAME}}", version="0.1.0")


@app.get("/health")
async def health() -> dict[str, str]:
    """Health check -- used by Docker HEALTHCHECK and load balancers."""
    health_status = {"status": "ok"}
    # -- dropwsl:health-checks --
    return health_status


@app.get("/")
def root() -> dict[str, str]:
    """Rota raiz."""
    return {"message": "Hello, World! 🚀"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)  # noqa: S104
