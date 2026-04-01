
# --- Lifespan: creates tables in dev ---
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    try:
        Base.metadata.create_all(bind=engine)  # dev only -- use Alembic in prod
    except Exception:
        logger.warning("Database unavailable -- tables not created. Run 'docker compose up -d'.")
    yield

