#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


def read_tsv(path: Path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))


def as_float(value, default=0.0):
    if value in (None, "", "NA"):
        return default
    return float(value)


def load_qc_expectations(path: Path):
    expectations = {}
    for row in read_tsv(path):
        expectations[row["metric"]] = {
            "minimum": as_float(row.get("minimum"), float("-inf")),
            "maximum": as_float(row.get("maximum"), float("inf")),
        }
    required = {"star_residual_pct", "kraken_human_pct"}
    missing = required - set(expectations)
    if missing:
        raise ValueError(
            "Missing QC expectation metric(s): " + ", ".join(sorted(missing))
        )
    return expectations


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate a biological mock-community pipeline run."
    )
    parser.add_argument("--results", required=True)
    parser.add_argument("--expected", required=True)
    parser.add_argument("--expected-qc", required=True)
    parser.add_argument("--sample", default="mock-community")
    args = parser.parse_args()

    results = Path(args.results)
    expected_rows = read_tsv(Path(args.expected))
    qc_expected = load_qc_expectations(Path(args.expected_qc))
    taxonomy_path = (
        results
        / "taxonomy"
        / "per_sample"
        / f"{args.sample}.taxonomy_comparison.tsv"
    )
    star_qc_path = (
        results
        / "host_depletion"
        / args.sample
        / f"{args.sample}.star_host_depletion_qc.tsv"
    )
    human_qc_path = (
        results
        / "kraken2"
        / args.sample
        / f"{args.sample}.kraken_human_qc.tsv"
    )

    missing = [
        str(path)
        for path in (taxonomy_path, star_qc_path, human_qc_path)
        if not path.is_file()
    ]
    if missing:
        raise SystemExit("Missing expected result file(s):\n  " + "\n  ".join(missing))

    taxonomy = {row["taxid"]: row for row in read_tsv(taxonomy_path)}
    failures = []

    for expected in expected_rows:
        taxid = expected["taxid"]
        row = taxonomy.get(taxid)
        min_kraken = int(expected.get("min_kraken_clade_reads", "0") or 0)
        min_kaiju = int(expected.get("min_kaiju_reads", "0") or 0)
        if row is None:
            if min_kraken > 0 or min_kaiju > 0:
                failures.append(
                    f"taxid {taxid} ({expected['name']}) missing from taxonomy table"
                )
            continue

        kraken_reads = int(float(row.get("kraken_clade_reads") or 0))
        kaiju_reads = int(float(row.get("kaiju_reads") or 0))
        if kraken_reads < min_kraken:
            failures.append(
                f"taxid {taxid} Kraken2 clade reads {kraken_reads} < expected minimum {min_kraken}"
            )
        if kaiju_reads < min_kaiju:
            failures.append(
                f"taxid {taxid} Kaiju reads {kaiju_reads} < expected minimum {min_kaiju}"
            )

    star_rows = read_tsv(star_qc_path)
    human_rows = read_tsv(human_qc_path)
    if len(star_rows) != 1 or len(human_rows) != 1:
        failures.append("QC outputs should each contain exactly one data row")
    else:
        residual = as_float(star_rows[0]["residual_pct"])
        human_pct = as_float(human_rows[0]["human_pct"])

        star_min = qc_expected["star_residual_pct"]["minimum"]
        star_max = qc_expected["star_residual_pct"]["maximum"]
        if not star_min <= residual <= star_max:
            failures.append(
                f"STAR residual_pct {residual:.3f} outside expected range {star_min:g}-{star_max:g}%"
            )

        human_min = qc_expected["kraken_human_pct"]["minimum"]
        human_max = qc_expected["kraken_human_pct"]["maximum"]
        if not human_min <= human_pct <= human_max:
            failures.append(
                f"Kraken2 residual human_pct {human_pct:.3f} outside expected range {human_min:g}-{human_max:g}%"
            )

    if failures:
        print("BIOLOGICAL TEST: FAIL")
        for failure in failures:
            print(f" - {failure}")
        raise SystemExit(1)

    print("BIOLOGICAL TEST: PASS")
    print(f" - taxonomy: {taxonomy_path}")
    print(f" - STAR QC: {star_qc_path}")
    print(f" - Kraken human QC: {human_qc_path}")


if __name__ == "__main__":
    main()
