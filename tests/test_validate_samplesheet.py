from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("validate_samplesheet", ROOT / "bin" / "validate_samplesheet.py")
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


class SamplesheetTests(unittest.TestCase):
    def test_relative_paths_resolve_from_sheet_directory(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            (tmp / "r1.fastq").write_text("@r1\nA\n+\nI\n")
            (tmp / "r2.fastq").write_text("@r2\nT\n+\nI\n")
            sheet = tmp / "samples.csv"
            sheet.write_text("sample,fastq_1,fastq_2\nS1,r1.fastq,r2.fastq\n")
            rows = MODULE.validate(sheet)
            self.assertEqual(rows[0][0], "S1")
            self.assertEqual(rows[0][1], (tmp / "r1.fastq").resolve())

    def test_duplicate_sample_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            sheet = tmp / "samples.csv"
            sheet.write_text(
                "sample,fastq_1,fastq_2\n"
                "S1,a,b\n"
                "S1,c,d\n"
            )
            with self.assertRaisesRegex(ValueError, "duplicate sample"):
                MODULE.validate(sheet, check_files=False)


if __name__ == "__main__":
    unittest.main()
