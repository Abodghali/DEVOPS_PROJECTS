import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parents[1] / 'app'))
from service import greeting, handle

class PreviewTest(unittest.TestCase):
    def test_greeting(self):
        self.assertEqual(greeting(' Ada ')['message'], 'Hello, Ada')
    def test_reject_blank(self):
        with self.assertRaises(ValueError): greeting(' ')
    def test_unknown(self):
        self.assertEqual(handle('GET','/missing',None,{})[0],404)
