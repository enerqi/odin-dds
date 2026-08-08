# `cmd.exe` for one reason: it starts in ~9ms. just launches a shell per recipe LINE, so shell startup
# is a fixed tax on every recipe. Bare `<shell> exit` under hyperfine: cmd ~9ms, `nu -c` ~41ms,
# `powershell -NoLogo -NoProfile -Command` ~143ms (what this file used to set - the slowest of the
# three, on a project where `just test` runs one compile per example file). cmd needs no `-NoProfile`
# guard for reproducibility either, because it has no profile to load. (src/build.cmd self-loads
# vcvars64, so the MSVC environment never came from a shell profile.)
#
# The cost is that cmd is a poor language for a multi-line recipe. So the three recipes that genuinely
# needed shell logic - `format`, `lint`, `test`, each of which loops over examples/*.odin - are now
# `[script("python")]` instead, which also collapses the [unix]/[windows] pairs they used to need into
# one body each. Several other pairs were byte-identical and are simply merged.
set windows-shell := ["cmd.exe", "/c"]
set shell := ["bash", "-c"]
set unstable  # [script("python")] and user-defined functions (`target_path`) are still gated
set lazy

# Set by the newest just feature used below - user-defined functions (1.49), for `target_path`.
# Older features also needed: `join()` 1.37, `set lazy` 1.47. Without this an old just reports a plain
# syntax error at the offending line, which reads like a corrupt justfile rather than an old tool.
set minimum-version := "1.49.0"

test_main_name := "test-main.exe"

# `join`, not the `/` operator: `/` always emits a forward slash, and cmd.exe rejects a forward-slash
# path in *command* position ("'target' is not recognized") even quoted. Odin takes either in an
# `-out:` argument, but the `rerun_*` recipes invoke the binary directly, so they need the native
# separator `join` gives. bash needs no `./` prefix - a path containing a slash is already a path, which
# is why the `./` those recipes used to carry is gone rather than made conditional.
target_path(dir, name) := join("target", dir, name)

# Which linker Odin hands the object files to. `-linker:` takes exactly four values: `default` (Odin
# picks - MSVC `link.exe` on Windows), `lld` (Windows and Linux; NOT on a stock macOS, where Odin
# links through Apple's clang and clang ships no lld), `radlink` (Windows only, and bundled with the
# Odin toolchain so it needs no install - which is why it is the Windows default here) and `mold`
# (Linux only, and not bundled - `apt install mold` first). Odin has no build cache and relinks on
# every `just run`, so the link step is a cost paid on each iteration - and every binary here links the
# DDS static archive on top of its own code, which makes the link the slower half of a rebuild.
#
# KNOWN radlink LIMIT, worth knowing before you debug your own code for it: the bridge deal-simulations
# consumer of these bindings (odin-sims) cannot use radlink at all. radlink there dies with its own
# `0xc000001d` (illegal instruction) crash, producing an .obj and no exe, at every optimization level,
# whenever live `core:debug/trace` code is linked alongside lib/dds.lib. The examples here do not use
# `core:debug/trace`, so radlink stays the default; if you add a segfault handler or an assert
# backtrace to one of them and the link starts crashing, that is this, and `ODIN_LINKER=default` is the
# answer. (Sibling odin-num-format hit the same class of failure via a Rust staticlib. `dbghelp.lib` in
# the link plus a static non-Odin library is the shape both share.)
#
# Override for a single command without editing this file. It is an env var rather than a recipe
# argument because `odin` errors on a repeated flag, so a `-linker:` passed through a recipe's *args
# would collide with the one the recipe already adds:
#
#     ODIN_LINKER=lld just run -lto:thin   # -lto on Windows *requires* -linker:lld
#
# See the odin-lang-skeleton justfile for the full per-value notes.
linker := env_var_or_default("ODIN_LINKER", if os() == "windows" { "radlink" } else { "default" })

# Avoids `odinfmt -w .` because src/prelude.odin is an incomplete bindgen template with no package
# line, which odinfmt exits non-zero on.
#
# This used to be a [unix]/[windows] pair, where the Windows copy ran a PowerShell one-liner afterwards
# to rewrite CRLF back to LF: odinfmt was writing CRLF on Windows and re-dirtying the working tree
# against an LF index, so a formatting pass produced a spurious line-endings-only diff. That was a
# missing setting, not a platform quirk - odinfmt.json had no `newline_style`, and odinfmt does not read
# .editorconfig's `end_of_line`. With `"newline_style": "LF"` in odinfmt.json (matching .editorconfig
# and .gitattributes' `* text=auto eol=lf`) odinfmt writes LF on every platform, so both the fixup and
# the platform split are gone.
# ---
# odinfmt the generated bindings + every example source (src/prelude.odin has no package line, so skip)
format:
	odinfmt -w dds.odin
	odinfmt -w examples


# lint the bindings, the shared `hands` package, and each single-file example (-file). The examples are
# each their own `package main`, so they cannot be checked as a directory - hence the loop, which is why
# this is a python recipe rather than a shell one (it replaces a bash `for` and a PowerShell
# `ForEach-Object` that had to be maintained in parallel). Accepts extra args like `--show-timings`.
# ---
# type check + vet + strict style
[script("python")]
lint *args:
	import glob, subprocess, sys

	extra = r'''{{args}}'''.split()
	FLAGS = ["-vet", "-vet-cast", "-strict-style", "-vet-tabs"]

	cmds = [
		["odin", "check", ".", *FLAGS, "-no-entry-point", *extra],
		["odin", "check", "examples/hands", *FLAGS, "-no-entry-point", *extra],
	]
	cmds += [
		["odin", "check", path, "-file", *FLAGS, *extra]
		for path in sorted(glob.glob("examples/*.odin"))
	]

	for cmd in cmds:
		rc = subprocess.run(cmd).returncode
		if rc != 0:
			raise SystemExit(rc)


# Every build recipe depends on this, so it runs before every build - which makes its cost a tax on
# every iteration. odin does not create the output directory (the linker fails with LNK1104), so this
# cannot be dropped.
# ---
# ensure the build artifacts top level directory exists
[unix]
@mktarget_dirs:
	mkdir -p target/debug target/fastdebug target/release

# `if not exist` rather than swallowing md's "already exists" with `2>nul`, so a genuine failure still
# sets a non-zero exit. `md target\<x>` creates `target` on the way, so it needs no line of its own.
# The loop variable is a single `%d`, NOT the `%%d` a .bat file would use: doubling is escaping for
# batch *files*, and `cmd /c` takes a command *line*.
# ---
# ensure the build artifacts top level directory exists
[windows]
@mktarget_dirs:
	for %d in (debug fastdebug release) do @if not exist target\%d md target\%d || exit /b 1

# both formatting and lint
qa: format lint

# run an example (examples/<name>.odin, default smoke) as a single-file program
# (-keep-executable so `rerun_debug` can skip recompiling)
# ---
# run an example (default smoke); e.g. `just run solve_board`
run_debug name="smoke" *args: mktarget_dirs
	odin run examples/{{name}}.odin -file -debug -microarch:native -show-timings -keep-executable -linker:{{linker}} -out:{{ target_path("debug", name + ".exe") }} {{args}}

alias run := run_debug

# run an example with debug + optimizations (-keep-executable so `rerun_fastdebug` can skip recompiling)
run_fastdebug name="smoke" *args: mktarget_dirs
	odin run examples/{{name}}.odin -file -debug -o:speed -microarch:native -show-timings -keep-executable -linker:{{linker}} -out:{{ target_path("fastdebug", name + ".exe") }} {{args}}

# run an example with optimizations (-keep-executable so `rerun_release` can skip recompiling)
run_release name="smoke" *args: mktarget_dirs
	odin run examples/{{name}}.odin -file -o:speed -microarch:native -show-timings -keep-executable -linker:{{linker}} -out:{{ target_path("release", name + ".exe") }} {{args}}

# re-run the last debug example binary WITHOUT recompiling (Odin has no build cache, so a plain `run`
# always rebuilds). Requires a prior `run_debug`/`run` of the same example.
# ---
# re-run the last debug example binary without recompiling
rerun_debug name="smoke" *args:
	{{ target_path("debug", name + ".exe") }} {{args}}

alias rerun := rerun_debug

# re-run the last fastdebug example binary without recompiling. Requires a prior `run_fastdebug`.
rerun_fastdebug name="smoke" *args:
	{{ target_path("fastdebug", name + ".exe") }} {{args}}

# re-run the last release example binary without recompiling. Requires a prior `run_release`.
rerun_release name="smoke" *args:
	{{ target_path("release", name + ".exe") }} {{args}}

# The tests live as @(test) procs INSIDE the single-file examples (examples/*.odin); there is no separate
# test package. Each example is its own `package main`, so (like `lint`) they compile one at a time with
# -file; `odin test` runs the @(test) procs and ignores `main`. Examples with no @(test) proc just print
# "No tests to run" (exit 0, harmless). The loop is why this is a python recipe - it replaces a bash
# `for` and a PowerShell `ForEach-Object` that had to say the same thing twice.
#
# ODIN_TEST_THREADS=1 forces the test runner to run @(test) procs serially. `odin test` otherwise runs
# them on a thread pool, but the DDS transposition-table pool is a process-global: one test's
# `defer dds.FreeMemory()` would tear it down under another test running concurrently -> race/crash.
# Today each example is a separate -file binary with one @(test), so nothing runs concurrently anyway;
# this pins it safe if a file ever gains a second @(test).
# ---
# run all tests (the @(test) procs inside examples/*.odin)
[script("python")]
test *args: mktarget_dirs
	import glob, os, subprocess

	out = os.path.join("target", "debug", "{{test_main_name}}")
	extra = r'''{{args}}'''.split()

	for path in sorted(glob.glob("examples/*.odin")):
		rc = subprocess.run([
			"odin", "test", path, "-file", "-debug", "-microarch:native",
			"-define:ODIN_TEST_THREADS=1", "-linker:{{linker}}", "-out:" + out, *extra,
		]).returncode
		if rc != 0:
			raise SystemExit(rc)

# Runs examples/<name>.odin. Filtering to a single @(test) proc is a `core:testing` define rather than a
# compiler flag - there is no `-test-name:`, and the stale spelling this comment used to suggest fails
# with `Unknown flag: 'test-name'` before anything builds:
#     just test1 solve_board -define:ODIN_TEST_NAMES=test_solve_board
# ODIN_TEST_THREADS=1: run serially -- see the `test` recipe for why (DDS FreeMemory is process-global).
# ---
# run one example's tests (e.g. `just test1 solve_board`)
test1 name *args: mktarget_dirs
	odin test examples/{{name}}.odin -file -debug -microarch:native -show-timings -define:ODIN_TEST_THREADS=1 -linker:{{linker}} -out:{{ target_path("debug", test_main_name) }} {{args}}

# simple delete of all debug databases and executables in the target directory
[unix]
clean:
	rm -rf target
	just mktarget_dirs

# cmd's equivalent of `rm -rf` is `rmdir /s /q`. Guarded by `if exist` because rmdir prints "The system
# cannot find the file specified" and exits non-zero on a missing path - the same reason the old
# PowerShell body needed its leading `-` to swallow the error.
# ---
# simple delete of all debug databases and executables in the target directory
[windows]
clean:
	if exist target rmdir /s /q target
	just mktarget_dirs

# build an example with verbose diagnostics
diagnose name="smoke" *args: mktarget_dirs
	odin build examples/{{name}}.odin -file -debug -microarch:native -show-more-timings -show-debug-messages -show-timings -linker:{{linker}} -out:{{ target_path("debug", name + ".exe") }} {{args}}


# Static, not DLL: the archive links and self-contains into one exe. Trade-off: DDS's DllMain/
# constructor auto-init does NOT run when statically linked -> consumers must call
# SetMaxThreads(0) once before use (see src/prelude.odin and examples/smoke.odin).
# Windows: src/build.cmd (MSVC cl+lib), stages lib/dds.lib.
# Unix:    src/Makefile  (g++/clang++ ar), stages lib/dds.a (Linux) or lib/darwin/dds.a (macOS).
# The DDS source is vendored in external/dds (see external/dds/VENDORED.md), so this needs no network.
# ---
# build the self-contained DDS static lib and stage it into ./lib
[unix]
build-lib:
	make -C src

# Called directly rather than through the `cmd /c '...'` wrapper the PowerShell version needed, and
# staged with cmd's own `md`/`copy` in place of `New-Item`/`cp` (which were PowerShell aliases, not
# programs, so they do not exist under cmd).
# ---
# build the self-contained DDS static lib and stage it into ./lib
[windows]
build-lib:
	src\build.cmd lib external\dds
	if not exist lib md lib
	copy /y external\dds\build\dds.lib lib\dds.lib


# bindgen names its output after the header stem (dll.h -> dll.odin), so it is renamed to dds.odin to
# match the package. Requires ../odin-c-bindgen. A python recipe because the rename used to be
# `mv -Force`, where `-Force` is a PowerShell Move-Item alias flag - so the recipe only ever worked in
# PowerShell, and would have failed under bash as well as cmd. `os.replace` overwrites on every
# platform.
# ---
# regenerate the Odin bindings from external/dds/include/dll.h
[script("python")]
bindgen:
	import os, subprocess

	binary = os.path.join("..", "odin-c-bindgen", "bindgen.exe")
	rc = subprocess.run([binary, "."]).returncode
	if rc != 0:
		raise SystemExit(rc)
	os.replace("dll.odin", "dds.odin")
	print("dll.odin -> dds.odin")
