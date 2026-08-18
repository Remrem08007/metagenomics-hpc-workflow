#!/usr/bin/env python3
import argparse
import csv
import gzip
import random
from pathlib import Path

DNA = set("ACGT")


def read_fasta(path: Path) -> str:
    seq = []
    with path.open("rt", encoding="utf-8") as handle:
        for line in handle:
            if not line.startswith(">"):
                seq.append(line.strip().upper())
    sequence = "".join(seq)
    if not sequence:
        raise ValueError(f"No sequence found in {path}")
    return sequence


def revcomp(seq: str) -> str:
    return seq.translate(str.maketrans("ACGT", "TGCA"))[::-1]


def choose_fragment(seq: str, fragment_length: int, read_length: int, rng: random.Random):
    if len(seq) < fragment_length:
        raise ValueError(
            f"Reference length {len(seq)} is shorter than fragment length {fragment_length}"
        )
    for _ in range(100000):
        start = rng.randrange(0, len(seq) - fragment_length + 1)
        fragment = seq[start : start + fragment_length]
        r1 = fragment[:read_length]
        r2 = revcomp(fragment[-read_length:])
        if set(r1) <= DNA and set(r2) <= DNA:
            return start, r1, r2
    raise ValueError("Could not find an A/C/G/T-only fragment after 100000 attempts")


def write_fastq_gz(path: Path, records) -> None:
    # mtime=0 makes the gzip byte stream reproducible as well as the read content.
    with path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as gz:
            for name, seq in records:
                payload = f"@{name}\n{seq}\n+\n{'I' * len(seq)}\n".encode()
                gz.write(payload)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a deterministic paired-end mock metagenomics mixture."
    )
    parser.add_argument(
        "--source",
        action="append",
        required=True,
        help="SOURCE,TAXID,ACCESSION,FASTA,PAIR_COUNT; repeat for each source",
    )
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--sample", default="mock-community")
    parser.add_argument("--read-length", type=int, default=150)
    parser.add_argument("--fragment-length", type=int, default=350)
    parser.add_argument("--seed", type=int, default=20260818)
    args = parser.parse_args()

    if args.read_length <= 0:
        parser.error("--read-length must be > 0")
    if args.fragment_length < args.read_length * 2:
        parser.error("--fragment-length must be at least 2 * --read-length")

    outdir = Path(args.output_dir).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    sources = []
    for raw in args.source:
        parts = raw.split(",", 4)
        if len(parts) != 5:
            parser.error(f"Invalid --source: {raw}")
        source, taxid, accession, fasta, count = parts
        count = int(count)
        if count <= 0:
            parser.error(f"PAIR_COUNT must be > 0: {raw}")
        sources.append((source, int(taxid), accession, Path(fasta).resolve(), count))

    rng = random.Random(args.seed)
    pairs = []
    truth = []
    serial = 0

    for source, taxid, accession, fasta, count in sources:
        seq = read_fasta(fasta)
        for _source_idx in range(1, count + 1):
            serial += 1
            start, r1, r2 = choose_fragment(
                seq, args.fragment_length, args.read_length, rng
            )
            pair_id = (
                f"{args.sample}.{serial:04d}|source={source}|taxid={taxid}|"
                f"accession={accession}"
            )
            pairs.append((pair_id, r1, r2))
            truth.append(
                (pair_id, source, taxid, accession, start + 1, args.fragment_length)
            )

    rng.shuffle(pairs)

    r1_path = outdir / f"{args.sample}_R1.fastq.gz"
    r2_path = outdir / f"{args.sample}_R2.fastq.gz"
    write_fastq_gz(r1_path, [(f"{name}/1", r1) for name, r1, _ in pairs])
    write_fastq_gz(r2_path, [(f"{name}/2", r2) for name, _, r2 in pairs])

    with (outdir / "ground_truth.tsv").open(
        "w", newline="", encoding="utf-8"
    ) as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(
            [
                "pair_id",
                "source",
                "taxid",
                "accession",
                "reference_start_1based",
                "fragment_length",
            ]
        )
        writer.writerows(truth)

    with (outdir / "samplesheet.csv").open(
        "w", newline="", encoding="utf-8"
    ) as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["sample", "fastq_1", "fastq_2"])
        writer.writerow([args.sample, str(r1_path), str(r2_path)])

    with (outdir / "mixture.tsv").open(
        "w", newline="", encoding="utf-8"
    ) as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(["source", "taxid", "accession", "pair_count"])
        for source, taxid, accession, _fasta, count in sources:
            writer.writerow([source, taxid, accession, count])

    print(outdir / "samplesheet.csv")


if __name__ == "__main__":
    main()
