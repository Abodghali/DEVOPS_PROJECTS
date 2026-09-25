import json
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1] / "app"))
from pipeline import aggregate, run


class PipelineTest(unittest.TestCase):
    def test_valid_and_rejected_events(self):
        report = aggregate(['{"status":200,"duration_ms":20}', '{"status":500,"duration_ms":40}', 'broken', '{"status":true,"duration_ms":5}'])
        self.assertEqual((report["accepted"], report["rejected"]), (2, 2))
        self.assertEqual(report["average_duration_ms"], 30)
        self.assertEqual(report["status_counts"]["5xx"], 1)

    def test_repeat_run_is_deterministic(self):
        with tempfile.TemporaryDirectory() as folder:
            source, dest = Path(folder) / "in.jsonl", Path(folder) / "report.json"
            source.write_text('{"status":200,"duration_ms":1}\n')
            run(source, dest)
            first = dest.read_bytes()
            run(source, dest)
            self.assertEqual(first, dest.read_bytes())

    def test_bad_batch_preserves_previous_report(self):
        with tempfile.TemporaryDirectory() as folder:
            source, dest = Path(folder) / "in.jsonl", Path(folder) / "report.json"
            source.write_text('invalid\n')
            dest.write_text('previous')
            with self.assertRaises(ValueError):
                run(source, dest)
            self.assertEqual(dest.read_text(), 'previous')
