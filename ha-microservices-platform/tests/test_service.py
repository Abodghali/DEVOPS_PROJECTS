import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).parents[1] / 'app'))
import service

class MicroservicesTest(unittest.TestCase):
    def test_price(self): self.assertEqual(service.price(3)['total_cents'],3750)
    def test_quantity_validation(self):
        with self.assertRaises(ValueError): service.price(True)
    def test_frontend(self):
        with patch.object(service,'ROLE','frontend'):
            self.assertIn('Service Catalog',service.handle('GET','/',None,{})[1])
    def test_fault_injection(self):
        with patch.dict(service.os.environ,{'INJECT_HTTP_500':'true'}):
            self.assertEqual(service.handle('GET','/',None,{})[0],500)
