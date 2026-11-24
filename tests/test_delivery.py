"""Exercise the shipped installer and verifier in disposable consumer repositories."""

import importlib.util
import os
from pathlib import Path
import shutil
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

    def write(self, name, content, mode=0o644):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        path.chmod(mode)
        return path

    def test_shell_suite_precedence_then_individual_scripts(self):
        self.write("tests/test_smoke test.sh", "#!/bin/sh\nexit 1\n", 0o755)
        self.write("scripts/test.sh", "#!/bin/sh\nprintf ran > receipt\n", 0o755)
        self.assertIn("SDM-VERIFY: PASS", self.verify())
        self.assertEqual((self.root / "receipt").read_text(), "ran")
        (self.root / "scripts/test.sh").unlink()
        self.assertIn("SDM-VERIFY: FAIL", self.verify(ok=False))
        self.write("tests/test_smoke test.sh", "#!/bin/sh\nexit 0\n", 0o755)
        self.assertIn("SDM-VERIFY: PASS", self.verify())

    @unittest.skipUnless(shutil.which("bats"), "Bats not installed")
    def test_bats_suite(self):
        for actual, ok in ((3, True), (4, False)):
            self.write("test/sums.bats", f'@test "sum" {{ [ "$((1+2))" -eq {actual} ]; }}\n')
            self.assertIn("bats test", self.verify(ok=ok))

    def test_missing_required_runner_fails_even_when_another_suite_passes(self):
        bin_dir = self.root / "available"
        bin_dir.mkdir()
        for tool in ("bash", "git", "mktemp", "grep", "tail", "date"):
            (bin_dir / tool).symlink_to(shutil.which(tool))
        self.write("tests/test_ok.sh", "#!/bin/sh\nexit 0\n", 0o755)
        self.write("tests/required.bats", '@test "required" { true; }\n')
        result = self.verify(ok=False, PATH=str(bin_dir))
        self.assertIn("PASS  test   ./tests/test_ok.sh", result)
        self.assertIn("FAIL  test   bats tests", result)

    def test_stdlib_suite_without_manifest_and_empty_collection(self):
        name = "tests/test_sum.py"
        for expected, ok in ((3, True), (4, False)):
            self.write(name, f"import unittest\nclass Totals(unittest.TestCase):\n"
                             f"    def test_sum(self): self.assertEqual(1 + 2, {expected})\n")
            self.assertIn("unittest-discover.py", self.verify(ok=ok, PYTHONDONTWRITEBYTECODE="1"))
        self.write(name, "def helper(): pass\n")
        self.assertIn("unittest collected no tests", self.verify(ok=False, PYTHONDONTWRITEBYTECODE="1"))
        (self.root / name).unlink()
        self.write("tests/__init__.py", "")
        self.write("tests/unit/__init__.py", "")
        self.write("tests/unit/values.py", "EXPECTED = 3\n")
        self.write("tests/unit/test_sum.py", "import unittest\nfrom .values import EXPECTED\n"
                   "class Totals(unittest.TestCase):\n    def test_sum(self): self.assertEqual(1 + 2, EXPECTED)\n")
        self.assertIn("SDM-VERIFY: PASS", self.verify(PYTHONDONTWRITEBYTECODE="1"))

    @unittest.skipUnless(importlib.util.find_spec("pytest"), "pytest not installed")
    def test_configured_pytest_without_packaging_manifest(self):
        self.write("pytest.ini", "[pytest]\n")
        for expected, ok in ((3, True), (4, False)):
            self.write("tests/test_sum.py", f"def test_sum(): assert 1 + 2 == {expected}\n")
            self.assertIn("-m pytest", self.verify(ok=ok, PYTHONDONTWRITEBYTECODE="1",
                                                   PYTEST_DISABLE_PLUGIN_AUTOLOAD="1"))

    @unittest.skipUnless(shutil.which("cargo"), "Cargo not installed")
    def test_cargo_suite(self):
        self.write("Cargo.toml", '[package]\nname = "sum"\nversion = "0.1.0"\nedition = "2021"\n')
        for expected, ok in ((3, True), (4, False)):
            self.write("src/lib.rs", f"#[test]\nfn sum() {{ assert_eq!(1 + 2, {expected}); }}\n")
            result = self.verify(ok=ok, CARGO_NET_OFFLINE="true")
            self.assertIn("cargo test", result)
            self.assertIn("cargo build", result)

    @unittest.skipUnless(shutil.which("go"), "Go not installed")
    def test_go_module_and_workspace_include_second_member(self):
        env = dict(GOTOOLCHAIN="local", GOPROXY="off", GOSUMDB="off",
                   GOCACHE=self.env.get("GOCACHE") or str(self.root / ".gocache"))
        self.write("go.mod", "module example.test/root\n\ngo 1.20\n")
        def suite(name, expected):
            self.write(name, 'package sum\nimport "testing"\nfunc TestSum(t *testing.T) {\n'
                             f'    if 1 + 2 != {expected} {{ t.Fatal("wrong sum") }}\n}}\n')
        suite("root_test.go", 3)
        self.assertIn("go test ./...", self.verify(GOWORK="off", **env))
        suite("root_test.go", 4)
        self.assertIn("wrong sum", self.verify(ok=False, GOWORK="off", **env))
        suite("root_test.go", 3)
        self.write("second member/go.mod", "module example.test/second\n\ngo 1.20\n")
        self.write("go.work", 'go 1.20\n\nuse (\n    .\n    "./second member"\n)\n')
        suite("second member/sum_test.go", 3)
        self.assertIn("go-workspace.sh test", self.verify(GOWORK="", **env))
        suite("second member/sum_test.go", 4)
        self.assertIn("wrong sum", self.verify(ok=False, GOWORK="", **env))
        (self.root / "go.mod").unlink()
        self.write("go.work", 'go 1.20\nuse "./second member"\n')
        suite("second member/sum_test.go", 3)
        self.assertIn("SDM-VERIFY: PASS", self.verify(GOWORK="", **env))
        with tempfile.TemporaryDirectory() as other:
            (Path(other) / "go.mod").write_text("module example.test/external\n\ngo 1.20\n")
            self.write("go.work", f'go 1.20\nuse "{Path(other).resolve()}"\n')
            self.assertIn("outside this checkout", self.verify(ok=False, GOWORK="", **env))

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

    def test_review_target_resolves_sole_unmerged_branch_and_rejects_ambiguity(self):
        script = str(SKILL / "scripts/review-target.sh")
        # Commit the installed skill on main first, matching a real project after install.
        self.cmd("git", "switch", "-q", "main")
        self.cmd("git", "add", ".")
        self.cmd("git", "-c", "commit.gpgsign=false", "commit", "--no-verify", "-qm", "chore: install sdm")
        base = self.cmd("git", "rev-parse", "HEAD").strip()
        self.cmd("git", "branch", "-qf", "feature/example", "main")
        self.cmd("git", "switch", "-q", "feature/example")

        self.assertIn("no unmerged work branch", self.cmd("bash", script, ok=False))

        self.write("docs/work/example/plan.md", "# 登录页改造\n")
        self.cmd("git", "add", ".")
        self.cmd("git", "-c", "commit.gpgsign=false", "commit", "-qm", "docs: plan for example")
        example_sha = self.cmd("git", "rev-parse", "HEAD").strip()

        # Works both on the work branch and when HEAD is back on main.
        for checkout in ("feature/example", "main"):
            self.cmd("git", "switch", "-q", checkout)
            resolved = self.cmd("bash", script)
            self.assertIn("BRANCH=feature/example\n", resolved)
            self.assertIn(f"SHA={example_sha}\n", resolved)
            self.assertIn(f"BASE={base}\n", resolved)
            self.assertIn("PLAN=docs/work/example/plan.md\n", resolved)
            self.assertIn("TITLE=登录页改造\n", resolved)

        # Once merged into main, the old branch is ignored when a new work branch opens.
        self.cmd("git", "merge", "--no-ff", "-qm", "Merge feature/example", "feature/example")
        merged_main = self.cmd("git", "rev-parse", "HEAD").strip()
        self.cmd("git", "switch", "-qc", "fix/export")
        self.write("docs/work/export/plan.md", "# 修复导出表格\n")
        self.cmd("git", "add", ".")
        self.cmd("git", "-c", "commit.gpgsign=false", "commit", "-qm", "docs: plan for export")
        export_sha = self.cmd("git", "rev-parse", "HEAD").strip()
        resolved = self.cmd("bash", script)
        self.assertIn("BRANCH=fix/export\n", resolved)
        self.assertIn(f"SHA={export_sha}\n", resolved)
        self.assertIn(f"BASE={merged_main}\n", resolved)

        # With two unmerged branches, bare review refuses to guess and surfaces plan titles.
        self.cmd("git", "switch", "-q", "main")
        self.cmd("git", "switch", "-qc", "feature/search")
        self.write("docs/work/search/plan.md", "# 搜索筛选\n")
        self.cmd("git", "add", ".")
        self.cmd("git", "-c", "commit.gpgsign=false", "commit", "-qm", "docs: plan for search")
        ambiguous = self.cmd("bash", script, ok=False)
        self.assertIn("multiple unmerged work branches", ambiguous)
        self.assertIn("fix/export — 修复导出表格", ambiguous)
        self.assertIn("feature/search — 搜索筛选 (checked out)", ambiguous)
        self.assertIn("BRANCH=fix/export\n", self.cmd("bash", script, "fix/export"))

