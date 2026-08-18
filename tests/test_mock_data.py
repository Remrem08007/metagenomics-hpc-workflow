import csv
import gzip
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
GENERATOR = REPO / "bin" / "generate_mock_fastqs.py"
VALIDATOR = REPO / "bin" / "validate_test_run.py"


class MockDataTests(unittest.TestCase):
    def test_generator_writes_expected_pair_counts(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            refs = {}
            for name, motif in {
                "human": "ACGT",
                "ecoli": "TGCA",
                "yeast": "GATC",
                "influenza": "CATG",
            }.items():
                path = tmp / f"{name}.fa"
                path.write_text(f">{name}\n{motif * 1000}\n")
                refs[name] = path

            out = tmp / "out"
            subprocess.run(
                [
                    sys.executable,
                    str(GENERATOR),
                    "--source",
                    f"human,9606,HUMAN,{refs['human']},4",
                    "--source",
                    f"ecoli,562,ECOLI,{refs['ecoli']},3",
                    "--source",
                    f"yeast,4932,YEAST,{refs['yeast']},2",
                    "--source",
                    f"influenza_a,11320,FLU,{refs['influenza']},1",
                    "--output-dir",
                    str(out),
                ],
                check=True,
            )

            with (out / "mixture.tsv").open() as handle:
                rows = list(csv.DictReader(handle, delimiter="\t"))
            self.assertEqual(sum(int(row["pair_count"]) for row in rows), 10)

            with gzip.open(out / "mock-community_R1.fastq.gz", "rt") as handle:
                self.assertEqual(sum(1 for _ in handle), 40)
            with gzip.open(out / "mock-community_R2.fastq.gz", "rt") as handle:
                self.assertEqual(sum(1 for _ in handle), 40)

            with (out / "ground_truth.tsv").open() as handle:
                truth = list(csv.DictReader(handle, delimiter="\t"))
            self.assertEqual(len(truth), 10)

    def test_biological_validator_passes_expected_fixture(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            results = tmp / "results"
            taxonomy = results / "taxonomy" / "per_sample"
            star = results / "host_depletion" / "mock-community"
            kraken = results / "kraken2" / "mock-community"
            taxonomy.mkdir(parents=True)
            star.mkdir(parents=True)
            kraken.mkdir(parents=True)

            (taxonomy / "mock-community.taxonomy_comparison.tsv").write_text(
                "sample\ttaxid\tname\tkraken_percent\tkraken_clade_reads\tkraken_taxon_reads\tkaiju_percent\tkaiju_reads\n"
                "mock-community\t562\tEscherichia coli\t30\t30\t0\t25\t20\n"
                "mock-community\t4932\tSaccharomyces cerevisiae\t20\t20\t0\t18\t15\n"
                "mock-community\t11320\tInfluenza A virus\t10\t10\t0\t0\t0\n"
            )
            (star / "mock-community.star_host_depletion_qc.tsv").write_text(
                "sample\tinput_reads\tresidual_pct\tthreshold_pct\tstatus\n"
                "mock-community\t100\t60\tNA\tPASS\n"
            )
            (kraken / "mock-community.kraken_human_qc.tsv").write_text(
                "sample\thuman_taxid\thuman_pct\tthreshold_pct\tstatus\n"
                "mock-community\t9606\t0\tNA\tPASS\n"
            )
            expected = tmp / "expected.tsv"
            expected.write_text(
                "taxid\tname\tmin_kraken_clade_reads\tmin_kaiju_reads\n"
                "562\tEscherichia coli\t1\t1\n"
                "4932\tSaccharomyces cerevisiae\t1\t1\n"
                "11320\tInfluenza A virus\t1\t0\n"
            )

            subprocess.run(
                [
                    sys.executable,
                    str(VALIDATOR),
                    "--results",
                    str(results),
                    "--expected",
                    str(expected),
                ],
                check=True,
            )


if __name__ == "__main__":
    unittest.main()
