#!/usr/bin/env python3
"""Generate host-depletion QC summaries and optionally enforce thresholds."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


def parse_star_log(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    with path.open() as handle:
        for line in handle:
            if "|" not in line:
                continue
            key, value = line.split("|", 1)
            values[key.strip()] = value.strip()
    return values


def percent(value: str | None) -> float:
    if not value:
        return 0.0
    return float(value.rstrip("%"))


def run_star(args: argparse.Namespace) -> int:
    values = parse_star_log(args.log)
    try:
        input_reads = int(values["Number of input reads"])
    except (KeyError, ValueError) as exc:
        raise ValueError(f"Could not parse STAR input-read count from {args.log}") from exc

    components = [
        "% of reads mapped to too many loci",
        "% of reads unmapped: too many mismatches",
        "% of reads unmapped: too short",
        "% of reads unmapped: other",
    ]
    residual_pct = sum(percent(values.get(key)) for key in components)
    threshold = args.max_unmapped_pct
    status = "PASS" if threshold is None or residual_pct <= threshold else "FAIL"

    with args.output.open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample", "input_reads", "residual_pct", "threshold_pct", "status"])
        writer.writerow([
            args.sample,
            input_reads,
            f"{residual_pct:.4f}",
            "NA" if threshold is None else threshold,
            status,
        ])

    if status == "FAIL":
        print(
            f"STAR host-depletion QC failed for {args.sample}: residual {residual_pct:.4f}% > {threshold}%",
            file=sys.stderr,
        )
        return 1
    return 0


def parse_kraken_human(path: Path, human_taxid: int) -> float | None:
    with path.open() as handle:
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 6:
                continue
            try:
                taxid = int(fields[4].strip())
                pct = float(fields[0].strip())
            except ValueError:
                continue
            if taxid == human_taxid:
                return pct
    return None


def run_kraken(args: argparse.Namespace) -> int:
    human_pct = parse_kraken_human(args.report, args.human_taxid)
    threshold = args.max_human_pct
    if human_pct is None:
        status = "NOT_FOUND" if threshold is None else "FAIL"
    else:
        status = "PASS" if threshold is None or human_pct <= threshold else "FAIL"

    with args.output.open("w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["sample", "human_taxid", "human_pct", "threshold_pct", "status"])
        writer.writerow([
            args.sample,
            args.human_taxid,
            "NA" if human_pct is None else f"{human_pct:.4f}",
            "NA" if threshold is None else threshold,
            status,
        ])

    if status == "FAIL":
        if human_pct is None:
            print(
                f"Kraken2 QC could not find human taxid {args.human_taxid} in {args.report}; "
                "cannot enforce --max-human-pct.",
                file=sys.stderr,
            )
        else:
            print(
                f"Kraken2 residual-human QC failed for {args.sample}: {human_pct:.4f}% > {threshold}%",
                file=sys.stderr,
            )
        return 1
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="mode", required=True)

    star = sub.add_parser("star")
    star.add_argument("--log", required=True, type=Path)
    star.add_argument("--sample", required=True)
    star.add_argument("--output", required=True, type=Path)
    star.add_argument("--max-unmapped-pct", type=float)

    kraken = sub.add_parser("kraken")
    kraken.add_argument("--report", required=True, type=Path)
    kraken.add_argument("--sample", required=True)
    kraken.add_argument("--human-taxid", type=int, default=9606)
    kraken.add_argument("--output", required=True, type=Path)
    kraken.add_argument("--max-human-pct", type=float)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        rc = run_star(args) if args.mode == "star" else run_kraken(args)
    except (OSError, ValueError) as exc:
        print(f"QC error: {exc}", file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(rc)


if __name__ == "__main__":
    main()
