from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin" / "validate_host_depletion.py"


class HostDepletionTests(unittest.TestCase):
    def test_star_threshold(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            log = tmp / "Log.final.out"
            out = tmp / "qc.tsv"
            log.write_text(
                "Number of input reads | 100\n"
                "% of reads mapped to too many loci | 1.00%\n"
                "% of reads unmapped: too many mismatches | 2.00%\n"
                "% of reads unmapped: too short | 3.00%\n"
                "% of reads unmapped: other | 4.00%\n"
            )
            ok = subprocess.run([
                sys.executable, str(SCRIPT), "star",
                "--log", str(log), "--sample", "S1", "--output", str(out),
                "--max-unmapped-pct", "10",
            ])
            self.assertEqual(ok.returncode, 0)
            fail = subprocess.run([
                sys.executable, str(SCRIPT), "star",
                "--log", str(log), "--sample", "S1", "--output", str(out),
                "--max-unmapped-pct", "9",
            ])
            self.assertEqual(fail.returncode, 1)


if __name__ == "__main__":
    unittest.main()
