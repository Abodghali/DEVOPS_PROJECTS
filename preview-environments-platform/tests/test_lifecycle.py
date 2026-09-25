import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]/'scripts'))
from render import namespace,owned,render

class LifecycleTest(unittest.TestCase):
    def test_names_are_project_scoped(self):
        self.assertNotEqual(namespace('1','2'),namespace('2','2'))
    def test_no_arbitrary_namespace(self):
        with self.assertRaises(ValueError): namespace('1','production')
        self.assertFalse(owned('production',{'preview-owner':'gitlab','gitlab-project':'1'},'1','2'))
    def test_resource_budget(self):
        docs=render('1','2','demo:1','reviews.lab.test')
        quota=next(d for d in docs if d['kind']=='ResourceQuota')
        self.assertEqual(quota['spec']['hard']['persistentvolumeclaims'],'0')
