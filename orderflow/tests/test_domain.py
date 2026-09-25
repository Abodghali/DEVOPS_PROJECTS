import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app"))
from domain import validate_order

class OrderTest(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(validate_order(dict(item=" Book ", quantity=2, unit_price_cents=1250)), ("Book", 2, 1250))

    def test_invalid_values(self):
        for field, values in {"item": [None, "", "x" * 101], "quantity": [True, 0, 1001, 1.2], "unit_price_cents": [False, -1, 1000001, "10"]}.items():
            for value in values:
                data = dict(item="Book", quantity=2, unit_price_cents=1250)
                data[field] = value
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    validate_order(data)

    def test_non_object(self):
        with self.assertRaises(ValueError):
            validate_order([])
