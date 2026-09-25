import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]/'app'))
from service import validate_note
class NoteTest(unittest.TestCase):
    def test_valid(self): self.assertEqual(validate_note({'text':'restore-marker'}),'restore-marker')
    def test_bad_values(self):
        for value in ({},[],{'text':''},{'text':'x'*201}):
            with self.assertRaises(ValueError): validate_note(value)
