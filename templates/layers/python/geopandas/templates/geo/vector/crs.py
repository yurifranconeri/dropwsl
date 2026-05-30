"""CRS constants and reprojection helpers.

Why a dedicated module?
- Area/length on a geographic CRS (degrees) is wrong by orders of magnitude.
- Always reproject to an equal-area projection before measuring area.
"""
from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from ._errors import GeoVectorError

if TYPE_CHECKING:
    from geopandas import GeoDataFrame

logger = logging.getLogger(__name__)

# Common CRS used in Brazilian geoprocessing.
SIRGAS_2000: str = "EPSG:4674"  # CAR / IBGE official datum (geographic)
WGS84: str = "EPSG:4326"        # Global geographic (GPS, GeoJSON default)
WEB_MERCATOR: str = "EPSG:3857"  # Web tiles (OSM, MapLibre, leaflet)
BRASIL_ALBERS: str = "EPSG:5880"  # Equal-area projection covering Brazil


def _require_crs(gdf: GeoDataFrame) -> None:
    if gdf.crs is None:
        raise GeoVectorError(
            "GeoDataFrame has no CRS. Set one explicitly with "
            "`gdf.set_crs('EPSG:4674', inplace=True)` if you know the source CRS."
        )


def reproject(gdf: GeoDataFrame, to: str | int) -> GeoDataFrame:
    """Reproject a GeoDataFrame to ``to`` (EPSG code as ``"EPSG:3857"`` or int).

    Returns a new GeoDataFrame; original is not mutated.
    """
    _require_crs(gdf)
    target = f"EPSG:{to}" if isinstance(to, int) else to
    logger.debug("Reprojecting %d features %s -> %s", len(gdf), gdf.crs, target)
    return gdf.to_crs(target)


def to_equal_area(gdf: GeoDataFrame) -> GeoDataFrame:
    """Reproject to an equal-area CRS suitable for measuring area.

    Strategy:
    - Bounds inside Brazil (approx) -> EPSG:5880 (Albers Equal Area Brasil).
    - Otherwise -> nearest UTM zone via ``gdf.estimate_utm_crs()``.
    """
    _require_crs(gdf)
    # Reproject to WGS84 just to inspect bounds in lon/lat.
    bounds_gdf = gdf if str(gdf.crs).upper() == WGS84 else gdf.to_crs(WGS84)
    minx, miny, maxx, maxy = bounds_gdf.total_bounds
    inside_brazil = (-74.0 <= minx <= -28.0) and (-74.0 <= maxx <= -28.0) \
        and (-34.0 <= miny <= 6.0) and (-34.0 <= maxy <= 6.0)
    if inside_brazil:
        return gdf.to_crs(BRASIL_ALBERS)
    return gdf.to_crs(gdf.estimate_utm_crs())
