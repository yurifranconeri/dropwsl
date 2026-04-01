import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from {{IMPORT_PREFIX}}db import service
from {{IMPORT_PREFIX}}db.engine import db_health, engine, get_session
from {{IMPORT_PREFIX}}db.models import Base, ItemModel

logger = logging.getLogger(__name__)
