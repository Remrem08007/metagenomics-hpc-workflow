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
    def test_generator_writes_expected_pair_counts_and_coordinates(self):
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
                    f"human,9606,HUMAN,{refs['human']},4,1001",
                    "--source",
                    f"ecoli,562,ECOLI,{refs['ecoli']},3,2001",
                    "--source",
                    f"yeast,4932,YEAST,{refs['yeast']},2,3001",
                    "--source",
                    f"influenza_a,11320,FLU,{refs['influenza']},1,1",
                    "--output-dir",
                    str(out),
                ],
                check=True,
            )

            with (out / "mixture.tsv").open() as handle:
                rows = list(csv.DictReader(handle, delimiter="\t"))
            self.assertEqual(sum(int(row["pair_count"]) for row in rows), 10)
            self.assertEqual(rows[0]["accession_region_start_1based"], "1001")

            with gzip.open(out / "mock-community_R1.fastq.gz", "rt") as handle:
                self.assertEqual(sum(1 for _ in handle), 40)
            with gzip.open(out / "mock-community_R2.fastq.gz", "rt") as handle:
                self.assertEqual(sum(1 for _ in handle), 40)

            with (out / "ground_truth.tsv").open() as handle:
                truth = list(csv.DictReader(handle, delimiter="\t"))
            self.assertEqual(len(truth), 10)

            first = truth[0]
            local_start = int(first["source_sequence_start_1based"])
            accession_start = int(first["accession_start_1based"])
            accession_end = int(first["accession_end_1based"])
            self.assertEqual(first["source"], "human")
            self.assertEqual(accession_start, 1001 + local_start - 1)
            self.assertEqual(accession_end, accession_start + 350 - 1)

    def test_biological_validator_supports_classifier_specific_taxids(self):
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
                "mock-community\t11320\tInfluenza A virus\t\t\t\t16.7\t10\n"
                "mock-community\t2955291\tAlphainfluenzavirus influenzae\t16.7\t10\t0\t\t\n"
            )
            (star / "mock-community.star_host_depletion_qc.tsv").write_text(
                "sample\tinput_reads\tresidual_pct\tthreshold_pct\tstatus\n"
                "mock-community\t100\t60\tNA\tPASS\n"
            )
            (kraken / "mock-community.kraken_human_qc.tsv").write_text(
                "sample\thuman_taxid\thuman_pct\tthreshold_pct\tstatus\n"
                "mock-community\t9606\tNA\tNA\tNOT_FOUND\n"
            )
            expected = tmp / "expected.tsv"
            expected.write_text(
                "source\tname\tkraken_taxid\tmin_kraken_clade_reads\tkaiju_taxid\tmin_kaiju_reads\n"
                "ecoli\tEscherichia coli\t562\t1\t562\t1\n"
                "yeast\tSaccharomyces cerevisiae\t4932\t1\t4932\t1\n"
                "influenza_a\tInfluenza A virus\t2955291\t1\t11320\t1\n"
            )
            expected_qc = tmp / "expected_qc.tsv"
            expected_qc.write_text(
                "metric\tminimum\tmaximum\tnote\n"
                "star_residual_pct\t45\t75\tfixture\n"
                "kraken_human_pct\t0\t5\tfixture\n"
            )

            subprocess.run(
                [
                    sys.executable,
                    str(VALIDATOR),
                    "--results",
                    str(results),
                    "--expected",
                    str(expected),
                    "--expected-qc",
                    str(expected_qc),
                ],
                check=True,
            )


if __name__ == "__main__":
    unittest.main()
