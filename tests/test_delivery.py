"""Exercise the shipped installer and verifier in disposable consumer repositories."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


KIT = Path(__file__).resolve().parents[1]
SKILL = Path(".agents/skills/sdm")


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name).resolve()
        self.env = dict(os.environ, GIT_AUTHOR_NAME="Tester", GIT_AUTHOR_EMAIL="test@example.invalid",
                        GIT_COMMITTER_NAME="Tester", GIT_COMMITTER_EMAIL="test@example.invalid")
        for key in ("SDM_BASE_SHA", "CI", "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
            self.env.pop(key, None)
        self.cmd("git", "init", "-q", "-b", "main")
        self.cmd("git", "-c", "commit.gpgsign=false", "commit", "-qm", "baseline", "--allow-empty")
        self.base = self.cmd("git", "rev-parse", "HEAD").strip()
        self.cmd("git", "switch", "-qc", "feature/example")
        (self.root / "AGENTS.md").write_text("Project-owned instructions.\n")
        self.install()

    def cmd(self, *args, env=None, ok=True):
        run = subprocess.run(args, cwd=self.root, env=dict(self.env, **(env or {})),
                             text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if (run.returncode == 0) != ok:
            self.fail(f"{args} returned {run.returncode}:\n{run.stdout}")
        return run.stdout

    def install(self, *args):
        self.cmd("bash", str(KIT / "install.sh"), str(self.root), *args)

    def verify(self, ok=True, **env):
        return self.cmd("bash", str(SKILL / "scripts/verify.sh"), env=dict(CI="true", **env), ok=ok)

    def test_install_and_upgrade_preserve_consumer_settings(self):
        self.assertEqual((self.root / ".claude/skills/sdm").resolve(), self.root / SKILL)
        skill = self.root / SKILL / "SKILL.md"
        skill.write_text("old installed skill\n")
        ci = self.root / ".github/workflows/sdm-verify.yml"
        ci.write_text("# project-owned workflow\n")
        for _ in range(2):
            self.install("--update")
        self.assertEqual(skill.read_bytes(), (KIT / SKILL / "SKILL.md").read_bytes())
        self.assertEqual(ci.read_text(), "# project-owned workflow\n")
        instructions = (self.root / "AGENTS.md").read_text()
        self.assertTrue(instructions.startswith("Project-owned instructions.\n"))
        self.assertEqual(instructions.count("<!-- SDM:BEGIN"), 1)
        self.assertEqual(self.cmd("git", "diff", "--cached", "--name-only"), "")

    def test_nested_swift_path_and_failure_propagation(self):
        # The stand-in validates the exact argv, including spaces and shell metacharacters.
        pkg = self.root / "Packages" / "Demo Kit; demo"
        pkg.mkdir(parents=True)
        (pkg / "Package.swift").touch()
        (self.root / "Demo.xcodeproj").mkdir()
        binary = self.root / "bin" / "swift"
        binary.parent.mkdir()
        binary.write_text('#!/bin/sh\n[ "$#" = 3 ] && [ "$1" = test ] && [ "$2" = --package-path ] && '
                          '[ "$3" = "Packages/Demo Kit; demo" ] && test -f "$3/pass"\n')
        binary.chmod(0o755)
        path = str(binary.parent) + os.pathsep + self.env["PATH"]
        self.assertIn("SDM-VERIFY: FAIL", self.verify(ok=False, PATH=path))
        (pkg / "pass").touch()
        evidence = self.verify(PATH=path)
        self.assertIn("SDM-VERIFY: PASS", evidence)
        self.assertIn("Xcode project detected", evidence)

    def test_ci_comparison_and_existing_makefile(self):
        (self.root / "Makefile").write_text("test:\n\t@test -f checked\n")
        self.assertIn("SDM-VERIFY: FAIL", self.verify(ok=False))
        (self.root / "checked").touch()
        self.cmd("git", "add", ".")
        self.cmd("git", "-c", "commit.gpgsign=false", "commit", "-qm", "test entry and rules")
        self.assertIn("Diff scan: NOT RUN", self.verify())
        compared = self.verify(SDM_BASE_SHA=self.base)
        self.assertIn(f"Diff scan: compared {self.base}", compared)
        self.assertIn("referee/check config changed", compared)
        self.assertIn("SDM-VERIFY: PASS", compared)
        self.assertIn("SDM_BASE_SHA", self.verify(ok=False, SDM_BASE_SHA="0" * 40))

    def test_existing_unknown_runner_is_not_silently_accepted(self):
        (self.root / "custom-test.sh").write_text("exit 0\n")
        self.assertIn("no supported test entry point", self.verify(ok=False))
