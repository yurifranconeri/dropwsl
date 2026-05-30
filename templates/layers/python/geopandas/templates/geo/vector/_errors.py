"""Errors raised by `geo.vector`."""
from __future__ import annotations


class GeoVectorError(Exception):
    """Raised on user-facing failures (missing CRS, unknown layer, bad path)."""
