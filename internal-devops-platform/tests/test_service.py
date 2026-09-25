import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]/'app'))
from service import summarize

class TelemetryTest(unittest.TestCase):
    def test_pipeline_counts(self):
        result=summarize([{'status':'success'},{'status':'failed'}],0)
        self.assertEqual(result['counts'],{'success':1,'failed':1})
    def test_queue_age(self):
        result=summarize([{'status':'pending','created_at':'1970-01-01T00:00:10Z'}],70)
        self.assertEqual(result['oldest_pending_seconds'],60)
    def test_empty_queue(self):
        self.assertEqual(summarize([],100)['oldest_pending_seconds'],0)
