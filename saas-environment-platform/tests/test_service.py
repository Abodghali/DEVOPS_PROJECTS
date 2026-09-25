import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).parents[1] / 'app'))
from service import quote, handle, ready

class PlansTest(unittest.TestCase):
    def test_quote(self):
        self.assertEqual(quote('team', 3)['monthly_cents'], 7200)
    def test_invalid_seats(self):
        for value in (True, 0, 1001, '3'):
            with self.assertRaises(ValueError): quote('team', value)
    def test_secret_required(self):
        with patch.dict(os.environ, {'API_TOKEN': 'test-only'}):
            self.assertTrue(ready())
            self.assertEqual(handle('POST', '/api/quote', {'plan':'team','seats':2}, {})[0], 401)
            self.assertEqual(handle('POST', '/api/quote', {'plan':'team','seats':2}, {'Authorization':'Bearer test-only'})[0], 200)
