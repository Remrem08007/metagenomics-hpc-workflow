from __future__ import annotations

import csv
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class MergeTaxonomyTests(unittest.TestCase):
    def test_merge_keeps_classifier_counts_separate(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            kraken = tmp / "kraken.tsv"
            kaiju = tmp / "kaiju.tsv"
            out = tmp / "out.tsv"
            kraken.write_text("90.00\t100\t90\tS\t562\tEscherichia coli\n")
            kaiju.write_text(
                "file\tpercent\treads\ttaxon_id\ttaxon_name\n"
                "sample.out\t80.0\t80\t562\tEscherichia coli\n"
            )
            subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "bin" / "merge_taxonomy.py"),
                    "--sample", "S1",
                    "--kraken", str(kraken),
                    "--kaiju", str(kaiju),
                    "--output", str(out),
                ],
                check=True,
            )
            with out.open() as handle:
                rows = list(csv.DictReader(handle, delimiter="\t"))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["kraken_taxon_reads"], "90")
            self.assertEqual(rows[0]["kaiju_reads"], "80")


if __name__ == "__main__":
    unittest.main()
