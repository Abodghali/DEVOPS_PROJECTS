import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]/'app'))
from recovery import measurements
class RecoveryTest(unittest.TestCase):
    def test_measured_intervals(self):
        result=measurements(100,125,90)
        self.assertEqual(result['rto_seconds'],25)
        self.assertEqual(result['rpo_seconds'],10)
    def test_invalid_clock_order(self):
        with self.assertRaises(ValueError): measurements(100,99,90)
