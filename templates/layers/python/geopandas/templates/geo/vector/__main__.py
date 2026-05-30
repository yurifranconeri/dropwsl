"""Command-line entry point: ``python -m geo.vector``.

Examples:
    python -m geo.vector                                       # demo on bundled fixture
    python -m geo.vector --in car.zip                          # info (lists layers if many)
    python -m geo.vector --in car.zip --layer AREA_IMOVEL
    python -m geo.vector --in car.zip --layer APP_TOTAL \\
                        --reproject EPSG:31983 --out data/interim/app.gpkg

Exit codes: 0 ok, 1 unexpected error, 2 user error (bad args, missing layer).
"""
from __future__ import annotations

import argparse
import logging
import sys
from importlib.resources import files
from pathlib import Path

from ._errors import GeoVectorError
from .io import read, write
from .ops import info as gdf_info

logger = logging.getLogger(__package__)

_DEMO_FIXTURE = files(__package__).joinpath("data/sample/brasil_regioes.geojson")


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog=f"python -m {__package__}",
        description="Read, reproject and measure vector data (SHP/GeoJSON/GPKG/Parquet/ZIP-CAR).",
    )
    p.add_argument("--in", dest="src", help="Input path (file or zip). Omit to run the bundled demo.")
    p.add_argument("--layer", help="Layer name (required when source has multiple layers).")
    p.add_argument("--reproject", metavar="EPSG", help='Reproject to CRS, e.g. "EPSG:3857".')
    p.add_argument("--out", help="Output path (writes the result; format inferred from extension).")
    p.add_argument(
        "--to",
        choices=("gpkg", "geojson", "parquet", "shp"),
        help="Force output driver (otherwise inferred from --out extension).",
    )
    p.add_argument("--fix-geometries", action="store_true", help="Apply make_valid() to geometries before output.")
    p.add_argument("--quiet", action="store_true", help="Suppress info banner; print only errors.")
    return p


def _print_info(label: str, info: dict[str, object]) -> None:
    bbox = info["bbox"]
    bbox_str = (
        f"({bbox[0]:.4f}, {bbox[1]:.4f}, {bbox[2]:.4f}, {bbox[3]:.4f})"
        if bbox else "(empty)"
    )
    area = info["total_area_ha"]
    area_str = f"{area:,.2f} ha" if isinstance(area, (int, float)) else "n/a"
    print(f"  {label}")
    print(f"  Features    : {info['n_features']}")
    print(f"  CRS         : {info['crs']}")
    print(f"  BBox        : {bbox_str}")
    print(f"  Total area  : {area_str}")
    geom_types = ", ".join(info["geometry_types"]) or "n/a"  # type: ignore[arg-type]
    print(f"  Geom types  : {geom_types}")


def _driver_from_to(to: str | None) -> str | None:
    if to is None:
        return None
    return {"gpkg": "GPKG", "geojson": "GeoJSON", "parquet": "Parquet", "shp": "ESRI Shapefile"}[to]


def _run_demo() -> int:
    print(f"[{__package__}] No --in provided. Running demo on bundled fixture:")
    print(f"            {_DEMO_FIXTURE}")
    print()
    gdf = read(str(_DEMO_FIXTURE))
    _print_info("Demo: brasil_regioes (5 macro-regions, simplified bounding boxes)", gdf_info(gdf))
    print()
    print("  Try next:")
    print(f"    python -m {__package__} --in <your_car.zip>")
    print(f"    python -m {__package__} --in <your_car.zip> --layer AREA_IMOVEL \\")
    print("                        --reproject EPSG:31983 --out data/interim/imovel.gpkg")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    logging.basicConfig(
        level=logging.WARNING if args.quiet else logging.INFO,
        format="%(message)s",
    )

    if args.src is None:
        return _run_demo()

    src = Path(args.src)
    gdf = read(src, layer=args.layer)

    if args.fix_geometries:
        from shapely import make_valid

        gdf = gdf.copy()
        gdf["geometry"] = gdf.geometry.apply(make_valid)

    if args.reproject:
        from .crs import reproject

        before_crs = str(gdf.crs)
        gdf = reproject(gdf, args.reproject)
        if not args.quiet:
            print(f"[{__package__}] Reprojected {len(gdf)} features {before_crs} -> {gdf.crs}")

    if args.out:
        write(gdf, args.out, driver=_driver_from_to(args.to))
        if not args.quiet:
            driver = _driver_from_to(args.to) or Path(args.out).suffix.lstrip(".").upper()
            print(f"[{__package__}] Written: {args.out} (driver={driver})")
        return 0

    label = f"Layer: {args.layer}" if args.layer else f"Source: {src}"
    if not args.quiet:
        _print_info(label, gdf_info(gdf))
    return 0


def _entrypoint() -> int:
    try:
        return main()
    except GeoVectorError as exc:
        print(f"[{__package__}] {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:  # pragma: no cover
        return 130
    except Exception as exc:  # pragma: no cover -- last-resort guard
        print(f"[{__package__}] unexpected error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(_entrypoint())
