#!/usr/bin/env python3
"""Merge Kraken2 and Kaiju species summaries side-by-side by NCBI taxid.

Counts from the two classifiers are intentionally not added or averaged.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def parse_kraken(path: Path) -> dict[int, dict[str, object]]:
    taxa: dict[int, dict[str, object]] = {}
    with path.open() as handle:
        for line in handle:
            if not line.strip():
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 6:
                continue
            percent, clade_reads, taxon_reads, rank, taxid, name = fields[:6]
            if rank.strip() != "S":
                continue
            try:
                tid = int(taxid.strip())
                pct = float(percent.strip())
                clade = int(clade_reads.strip())
                direct = int(taxon_reads.strip())
            except ValueError:
                continue
            taxa[tid] = {
                "name": name.strip(),
                "kraken_percent": pct,
                "kraken_clade_reads": clade,
                "kraken_taxon_reads": direct,
            }
    return taxa


def parse_kaiju(path: Path) -> dict[int, dict[str, object]]:
    taxa: dict[int, dict[str, object]] = {}
    with path.open() as handle:
        for line in handle:
            if not line.strip() or line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 5:
                continue
            _source, percent, reads, taxid, name = fields[:5]
            try:
                tid = int(taxid.strip())
                pct = float(percent.strip())
                count = int(reads.strip())
            except ValueError:
                # Header and non-taxon summary rows are ignored.
                continue
            taxa[tid] = {
                "name": name.strip(),
                "kaiju_percent": pct,
                "kaiju_reads": count,
            }
    return taxa


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample", required=True)
    parser.add_argument("--kraken", required=True, type=Path)
    parser.add_argument("--kaiju", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    kraken = parse_kraken(args.kraken)
    kaiju = parse_kaiju(args.kaiju)
    taxids = sorted(set(kraken) | set(kaiju))

    fields = [
        "sample",
        "taxid",
        "name",
        "kraken_percent",
        "kraken_clade_reads",
        "kraken_taxon_reads",
        "kaiju_percent",
        "kaiju_reads",
    ]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, delimiter="\t")
        writer.writeheader()
        for taxid in taxids:
            k = kraken.get(taxid, {})
            j = kaiju.get(taxid, {})
            writer.writerow(
                {
                    "sample": args.sample,
                    "taxid": taxid,
                    "name": k.get("name") or j.get("name") or "",
                    "kraken_percent": k.get("kraken_percent", ""),
                    "kraken_clade_reads": k.get("kraken_clade_reads", ""),
                    "kraken_taxon_reads": k.get("kraken_taxon_reads", ""),
                    "kaiju_percent": j.get("kaiju_percent", ""),
                    "kaiju_reads": j.get("kaiju_reads", ""),
                }
            )


if __name__ == "__main__":
    main()
