"""I/O for vector data (SHP, GeoJSON, GeoPackage, GeoParquet, ZIP-CAR).

Engine: ``pyogrio`` (fast, wheel-bundled GDAL).
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import TYPE_CHECKING

from ._errors import GeoVectorError

if TYPE_CHECKING:
    from geopandas import GeoDataFrame

logger = logging.getLogger(__name__)

# Driver inferred from file extension on `write()` when none provided.
_EXT_TO_DRIVER: dict[str, str] = {
    ".gpkg": "GPKG",
    ".geojson": "GeoJSON",
    ".json": "GeoJSON",
    ".shp": "ESRI Shapefile",
    ".parquet": "Parquet",
}


def list_layers(path: str | Path) -> list[str]:
    """List vector layers available at ``path`` (multi-layer GPKG, ZIP, ...)."""
    import pyogrio

    info_arr = pyogrio.list_layers(str(path))
    # pyogrio returns ndarray of [layer_name, geometry_type] rows.
    return [str(row[0]) for row in info_arr]


def read(path: str | Path, layer: str | None = None) -> GeoDataFrame:
    """Read a vector dataset into a GeoDataFrame.

    Supports SHP, GeoJSON, GeoPackage, GeoParquet and ZIP archives (CAR ships zipped).

    Raises ``GeoVectorError`` when ``layer`` is omitted on a multi-layer source.
    """
    import geopandas as gpd  # heavy import — keep lazy

    p = Path(path)
    if not p.exists():
        raise GeoVectorError(f"File not found: {p}")

    if p.suffix.lower() == ".parquet":
        # GeoParquet has its own reader (no `engine` kwarg).
        if layer is not None:
            raise GeoVectorError("GeoParquet has no `layer` concept; drop --layer.")
        logger.debug("Reading GeoParquet: %s", p)
        return gpd.read_parquet(p)

    if layer is None:
        layers = list_layers(p)
        if len(layers) > 1:
            joined = "\n              ".join(layers)
            raise GeoVectorError(
                f"Multiple layers detected. Pick one with --layer:\n              {joined}"
            )
        layer = layers[0] if layers else None

    logger.debug("Reading %s (layer=%s) via pyogrio", p, layer)
    return gpd.read_file(p, layer=layer, engine="pyogrio", use_arrow=True)


def write(
    gdf: GeoDataFrame,
    path: str | Path,
    driver: str | None = None,
) -> None:
    """Write a GeoDataFrame, inferring the driver from the file extension."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)

    if driver is None:
        driver = _EXT_TO_DRIVER.get(p.suffix.lower())
        if driver is None:
            raise GeoVectorError(
                f"Cannot infer driver from extension '{p.suffix}'. "
                f"Pass --to {{gpkg,geojson,parquet,shp}} or use a known suffix."
            )

    if driver == "Parquet":
        logger.debug("Writing GeoParquet: %s", p)
        gdf.to_parquet(p)
        return

    logger.debug("Writing %s via pyogrio (driver=%s)", p, driver)
    gdf.to_file(p, driver=driver, engine="pyogrio")
