"""Vector geoprocessing primitives (read, reproject, measure)."""
from __future__ import annotations

from ._errors import GeoVectorError
from .crs import (
    BRASIL_ALBERS,
    SIRGAS_2000,
    WEB_MERCATOR,
    WGS84,
    reproject,
    to_equal_area,
)
from .io import read, write
from .ops import area_ha, bbox, info

__all__ = [
    "BRASIL_ALBERS",
    "GeoVectorError",
    "SIRGAS_2000",
    "WEB_MERCATOR",
    "WGS84",
    "area_ha",
    "bbox",
    "info",
    "read",
    "reproject",
    "to_equal_area",
    "write",
]
