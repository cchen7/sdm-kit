"""Run conventional stdlib suites; older Python versions exit zero for an empty suite."""

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path.cwd()))
start = Path(sys.argv[1])
top = str(Path.cwd()) if (start / "__init__.py").is_file() else None
suite = unittest.defaultTestLoader.discover(str(start), top_level_dir=top)
if not suite.countTestCases():
    sys.exit("SDM: unittest collected no tests; declare pytest or expose the project runner via make test.")
sys.exit(0 if unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful() else 1)
