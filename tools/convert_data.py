import argparse
import os
import sqlite3
from pathlib import Path

import pandas as pd

SQLITE_SUFFIXES = {".sqlite", ".sqlite3", ".db"}


def quote_identifier(name: str) -> str:
    """Quote SQLite identifier safely."""
    return '"' + name.replace('"', '""') + '"'


def xlsx_path_for_db(db_path: Path, output: str | None = None, root: Path | None = None) -> Path:
    """Return output xlsx path for one db."""
    if output is None:
        return db_path.with_suffix(".xlsx")

    out = Path(output)
    if root is None or not root.is_dir():
        return out

    rel = db_path.relative_to(root)
    return (out / rel).with_suffix(".xlsx")


def sqlite_to_xlsx(db_path: Path, output_path: Path) -> bool:
    """Convert all tables in a SQLite DB to sheets in an XLSX file."""
    print(f"Converting {db_path} -> {output_path}...", flush=True)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        with sqlite3.connect(db_path) as conn:
            tables = pd.read_sql_query(
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name", conn
            )
            table_names = tables["name"].tolist()

            if not table_names:
                print(f"  [SKIP] No tables found: {db_path}", flush=True)
                return False

            with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
                for table in table_names:
                    sheet_name = table[:31]
                    print(f"  Exporting table: {table} -> sheet: {sheet_name}", flush=True)
                    df = pd.read_sql_query(f"SELECT * FROM {quote_identifier(table)}", conn)
                    df.to_excel(writer, sheet_name=sheet_name, index=False)

        print(f"Successfully converted to {output_path}", flush=True)
        return True
    except Exception as exc:
        print(f"  [ERROR] {db_path}: {exc}", flush=True)
        return False


def iter_sqlite_files(folder: Path):
    """Yield sqlite-like files recursively under folder."""
    for path in sorted(folder.rglob("*")):
        if path.is_file() and path.suffix.lower() in SQLITE_SUFFIXES:
            yield path


def convert_path(db_path: str, output: str | None = None) -> int:
    """Convert one SQLite file, or all SQLite files recursively under a folder."""
    src = Path(db_path)
    if src.is_dir():
        out_root = Path(output) if output else src
        db_files = list(iter_sqlite_files(src))
        print(f"Found {len(db_files)} SQLite file(s) under {src}", flush=True)
        ok = 0
        for db_file in db_files:
            out_file = xlsx_path_for_db(db_file, output=str(out_root), root=src)
            if sqlite_to_xlsx(db_file, out_file):
                ok += 1
        print(f"Done: {ok}/{len(db_files)} converted", flush=True)
        return 0 if ok == len(db_files) else 1

    out_file = xlsx_path_for_db(src, output=output)
    return 0 if sqlite_to_xlsx(src, out_file) else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert SQLite DB(s) to XLSX")
    parser.add_argument("db_path", help="SQLite database file, or folder to scan recursively")
    parser.add_argument(
        "-o",
        "--output",
        help=(
            "Output XLSX file path for single DB, or output folder for directory input "
            "(defaults beside each DB)"
        ),
    )

    args = parser.parse_args()
    raise SystemExit(convert_path(args.db_path, args.output))
