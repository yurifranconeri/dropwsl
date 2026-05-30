"""Pure operations on GeoDataFrames (info, area, bbox)."""
from __future__ import annotations

import logging
from typing import TYPE_CHECKING, Any

from .crs import to_equal_area

if TYPE_CHECKING:
    import pandas as pd
    from geopandas import GeoDataFrame

logger = logging.getLogger(__name__)


def bbox(gdf: GeoDataFrame) -> tuple[float, float, float, float]:
    """Return ``(minx, miny, maxx, maxy)`` in the GeoDataFrame's current CRS."""
    minx, miny, maxx, maxy = gdf.total_bounds
    return float(minx), float(miny), float(maxx), float(maxy)


def area_ha(gdf: GeoDataFrame) -> pd.Series:
    """Return per-feature area in hectares.

    Always reprojects to an equal-area CRS first (geographic CRS would yield
    nonsense values in degrees-squared).
    """
    projected = to_equal_area(gdf)
    return projected.geometry.area / 10_000.0


def info(gdf: GeoDataFrame) -> dict[str, Any]:
    """Return a JSON-friendly summary of a GeoDataFrame."""
    crs_str = str(gdf.crs) if gdf.crs is not None else None
    total_area_ha: float | None
    try:
        total_area_ha = float(area_ha(gdf).sum()) if len(gdf) else 0.0
    except Exception as exc:  # pragma: no cover — defensive only
        logger.debug("area_ha failed: %s", exc)
        total_area_ha = None
    return {
        "n_features": int(len(gdf)),
        "crs": crs_str,
        "bbox": bbox(gdf) if len(gdf) else None,
        "total_area_ha": total_area_ha,
        "columns": [str(c) for c in gdf.columns if c != gdf.geometry.name],
        "geometry_types": sorted({str(t) for t in gdf.geom_type.unique()}),
    }
