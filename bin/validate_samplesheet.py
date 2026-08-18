#!/usr/bin/env python3
"""Validate the public pipeline's paired-end samplesheet."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

SAMPLE_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
REQUIRED = ("sample", "fastq_1", "fastq_2")


def validate(path: Path, check_files: bool = True) -> list[tuple[str, Path, Path]]:
    path = path.resolve()
    if not path.is_file():
        raise ValueError(f"Samplesheet not found: {path}")

    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise ValueError("Samplesheet is empty")
        missing = [name for name in REQUIRED if name not in reader.fieldnames]
        if missing:
            raise ValueError(f"Missing samplesheet column(s): {', '.join(missing)}")

        rows: list[tuple[str, Path, Path]] = []
        seen: set[str] = set()
        for line_no, row in enumerate(reader, start=2):
            sample = (row.get("sample") or "").strip()
            r1_raw = (row.get("fastq_1") or "").strip()
            r2_raw = (row.get("fastq_2") or "").strip()
            if not sample or not r1_raw or not r2_raw:
                raise ValueError(f"Line {line_no}: sample, fastq_1 and fastq_2 are required")
            if not SAMPLE_RE.fullmatch(sample):
                raise ValueError(
                    f"Line {line_no}: invalid sample '{sample}'; use letters, numbers, '.', '_' or '-'"
                )
            if sample in seen:
                raise ValueError(f"Line {line_no}: duplicate sample '{sample}'")
            seen.add(sample)

            r1 = Path(r1_raw)
            r2 = Path(r2_raw)
            if not r1.is_absolute():
                r1 = (path.parent / r1).resolve()
            if not r2.is_absolute():
                r2 = (path.parent / r2).resolve()
            if check_files:
                if not r1.is_file():
                    raise ValueError(f"Line {line_no}: FASTQ not found: {r1}")
                if not r2.is_file():
                    raise ValueError(f"Line {line_no}: FASTQ not found: {r2}")
            rows.append((sample, r1, r2))

    if not rows:
        raise ValueError("Samplesheet contains no samples")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--no-check-files", action="store_true")
    args = parser.parse_args()
    rows = validate(args.input, check_files=not args.no_check_files)
    print(f"Samplesheet OK: {len(rows)} sample(s)")


if __name__ == "__main__":
    main()
