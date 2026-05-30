# `geo.vector` — vector geoprocessing

Read, reproject and measure vector data (SHP, GeoJSON, GeoPackage, GeoParquet, ZIP-CAR).

> **Note on import path.** This package lives inside your project. Examples below
> use `geo.vector` (flat layout). If your project uses `src/` layout, prefix with
> your package name, e.g. `python -m my_pkg.geo.vector` and
> `from my_pkg.geo.vector import ...`.

## Quick start (CLI)

```bash
# Demo on the bundled fixture (5 simplified macro-regions of Brazil, EPSG:4674)
python -m geo.vector

# Inspect a CAR archive (lists layers if there are many)
python -m geo.vector --in data/raw/CAR_MG_3100104.zip

# Inspect a specific layer
python -m geo.vector --in data/raw/CAR_MG_3100104.zip --layer AREA_IMOVEL

# Reproject and save (driver inferred from extension: .gpkg/.parquet/.geojson/.shp)
python -m geo.vector \
    --in data/raw/CAR_MG_3100104.zip \
    --layer APP_TOTAL \
    --reproject EPSG:31983 \
    --out data/interim/app_utm.gpkg
```

Exit codes: `0` ok, `1` unexpected error, `2` user error (bad args, missing `--layer`).

## Quick start (Python)

```python
from geo.vector import read, reproject, area_ha, info

gdf = read("data/raw/CAR_MG_3100104.zip", layer="AREA_IMOVEL")
gdf_3857 = reproject(gdf, "EPSG:3857")
print(info(gdf))                # {'n_features': 1, 'crs': 'EPSG:4674', ...}
print(area_ha(gdf).sum())       # area in hectares (correctly projected)
```

## Where to put your data

Convention (Cookiecutter Data Science):

```
data/
├── raw/         # original CAR.zip, DEM.tif, ortophotos — never edited
├── interim/     # reprojected, clipped, intermediate artifacts
└── processed/   # final outputs (GeoParquet, GPKG)
```

`data/` is gitignored by this layer. Add files manually with `git add -f` if needed.

## Reference

| Symbol | What it does |
|---|---|
| `read(path, layer=None) -> GeoDataFrame` | Read SHP/GeoJSON/GPKG/Parquet/ZIP via `pyogrio`. Lists layers when ambiguous. |
| `write(gdf, path, driver=None) -> None` | Write; driver inferred from extension. |
| `reproject(gdf, to) -> GeoDataFrame` | Reproject to `"EPSG:NNNN"` (or `int`). |
| `to_equal_area(gdf) -> GeoDataFrame` | Reproject to `EPSG:5880` (Brazil) or estimated UTM (elsewhere). |
| `area_ha(gdf) -> pd.Series` | Per-feature area in hectares (always via `to_equal_area`). |
| `bbox(gdf) -> tuple[float, ...]` | `(minx, miny, maxx, maxy)` in current CRS. |
| `info(gdf) -> dict` | JSON-friendly summary (features, CRS, bbox, area, columns, geometry types). |
| `GeoVectorError` | Raised on user-facing failures (missing CRS, unknown layer, bad path). |

## Design notes

- **Engine:** `pyogrio` everywhere (5–20× faster than `fiona`; ships GDAL via wheel).
- **Area is never computed in a geographic CRS.** `area_ha` always reprojects first.
- **Self-contained:** does not modify `main.py`; import what you need in one line.
