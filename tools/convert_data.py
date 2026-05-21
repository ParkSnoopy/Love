import sqlite3
import pandas as pd
import argparse
import os


def sqlite_to_xlsx(db_path: str, output_path: str):
    """Convert all tables in a SQLite DB to sheets in an XLSX file."""
    print(f"Converting {db_path} -> {output_path}...")

    try:
        conn = sqlite3.connect(db_path)
        # Get all table names
        tables = pd.read_sql_query(
            "SELECT name FROM sqlite_master WHERE type='table'", conn
        )
        table_names = tables["name"].tolist()

        if not table_names:
            print("No tables found in database.")
            return

        with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
            for table in table_names:
                print(f"  Exporting table: {table}")
                df = pd.read_sql_query(f"SELECT * FROM {table}", conn)
                df.to_excel(writer, sheet_name=table, index=False)

        print(f"Successfully converted to {output_path}")
    except Exception as e:
        print(f"Error during conversion: {e}")
    finally:
        conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert SQLite DB to XLSX")
    parser.add_argument("db_path", help="Path to the SQLite database file")
    parser.add_argument(
        "-o",
        "--output",
        help="Output XLSX file path (defaults to .xlsx version of db_path)",
    )

    args = parser.parse_args()

    db_file = args.db_path
    out_file = args.output or (os.path.splitext(db_file)[0] + ".xlsx")

    sqlite_to_xlsx(db_file, out_file)
