set windows-shell := ["powershell", "-NoLogo", "-Command"]
set shell := ["bash", "-c"]

test_main_name := "test-main.exe"

# odinfmt the generated bindings + every example source (src/prelude.odin has no package line, so skip)
[unix]
format:
	odinfmt -w dds.odin
	odinfmt -w examples

# odinfmt ignores .editorconfig end_of_line=lf and writes CRLF on Windows, re-dirtying the working tree
# (index stays LF via .gitattributes, so it shows as a spurious line-endings-changed diff). Convert back
# to LF after formatting so the working tree matches the index.
[windows]
format:
	odinfmt -w dds.odin
	odinfmt -w examples
	Get-ChildItem dds.odin, examples/*.odin -File | ForEach-Object { $t = [IO.File]::ReadAllText($_.FullName); [IO.File]::WriteAllText($_.FullName, ($t -replace "`r`n", "`n")) }


# lint the bindings, the shared `hands` package, and each single-file example (-file). Accepts extra
# args like `--show-timings`.
# ---
# type check + vet + strict style
[unix]
lint *args:
	odin check . -vet -vet-cast -strict-style -no-entry-point {{args}}
	odin check examples/hands -vet -vet-cast -strict-style -no-entry-point {{args}}
	for f in examples/*.odin; do odin check "$f" -file -vet -vet-cast -strict-style {{args}} || exit 1; done

# type check + vet + strict style
[windows]
lint *args:
	odin check . -vet -vet-cast -strict-style -no-entry-point {{args}}
	odin check examples/hands -vet -vet-cast -strict-style -no-entry-point {{args}}
	Get-ChildItem examples/*.odin | ForEach-Object { odin check $_.FullName -file -vet -vet-cast -strict-style {{args}}; if ($LASTEXITCODE -ne 0) { exit 1 } }


# ensure the build artifacts top level directory exists
[unix]
@mktarget_dirs:
	-mkdir -p target
	-mkdir -p target/debug
	-mkdir -p target/fastdebug
	-mkdir -p target/release

# ensure the build artifacts top level directory exists
[windows]
@mktarget_dirs:
	New-Item -ItemType Directory -Force target, target/debug, target/fastdebug, target/release | Out-Null

# run an example (examples/<name>.odin, default smoke) as a single-file program
# (-keep-executable so `rerun_debug` can skip recompiling)
# ---
# run an example (default smoke); e.g. `just run solve_board`
run_debug name="smoke" *args: mktarget_dirs
	odin run examples/{{name}}.odin -file -debug -microarch:native -show-timings -keep-executable -out:target/debug/{{name}}.exe {{args}}

alias run := run_debug

# run an example with debug + optimizations (-keep-executable so `rerun_fastdebug` can skip recompiling)
run_fastdebug name="smoke" *args: mktarget_dirs
	odin run examples/{{name}}.odin -file -debug -o:speed -microarch:native -show-timings -keep-executable -out:target/fastdebug/{{name}}.exe {{args}}

# run an example with optimizations (-keep-executable so `rerun_release` can skip recompiling)
run_release name="smoke" *args: mktarget_dirs
	odin run examples/{{name}}.odin -file -o:speed -microarch:native -show-timings -keep-executable -out:target/release/{{name}}.exe {{args}}

# re-run the last debug example binary WITHOUT recompiling (Odin has no build cache, so a plain `run`
# always rebuilds). Requires a prior `run_debug`/`run` of the same example.
# ---
# re-run the last debug example binary without recompiling
rerun_debug name="smoke" *args:
	./target/debug/{{name}}.exe {{args}}

alias rerun := rerun_debug

# re-run the last fastdebug example binary without recompiling. Requires a prior `run_fastdebug`.
rerun_fastdebug name="smoke" *args:
	./target/fastdebug/{{name}}.exe {{args}}

# re-run the last release example binary without recompiling. Requires a prior `run_release`.
rerun_release name="smoke" *args:
	./target/release/{{name}}.exe {{args}}

# The tests live as @(test) procs INSIDE the single-file examples (examples/*.odin); there is no separate
# test package. Each example is its own `package main`, so (like `lint`) they compile one at a time with
# -file; `odin test` runs the @(test) procs and ignores `main`. Examples with no @(test) proc just print
# "No tests to run" (exit 0, harmless).
#
# ODIN_TEST_THREADS=1 forces the test runner to run @(test) procs serially. `odin test` otherwise runs
# them on a thread pool, but the DDS transposition-table pool is a process-global: one test's
# `defer dds.FreeMemory()` would tear it down under another test running concurrently -> race/crash.
# Today each example is a separate -file binary with one @(test), so nothing runs concurrently anyway;
# this pins it safe if a file ever gains a second @(test).
# ---
# run all tests (the @(test) procs inside examples/*.odin)
[unix]
test *args: mktarget_dirs
	for f in examples/*.odin; do odin test "$f" -file -debug -microarch:native -define:ODIN_TEST_THREADS=1 -out:target/debug/{{test_main_name}} {{args}} || exit 1; done

# run all tests (the @(test) procs inside examples/*.odin)
[windows]
test *args: mktarget_dirs
	Get-ChildItem examples/*.odin | ForEach-Object { odin test $_.FullName -file -debug -microarch:native -define:ODIN_TEST_THREADS=1 -out:target/debug/{{test_main_name}} {{args}}; if ($LASTEXITCODE -ne 0) { exit 1 } }

# Runs examples/<name>.odin. Filter to a single @(test) proc with extra args, e.g.
# `just test1 solve_board -test-name:test_solve_board`. ODIN_TEST_THREADS=1: run serially -- see the
# `test` recipe for why (DDS FreeMemory is process-global).
# ---
# run one example's tests (e.g. `just test1 solve_board`)
test1 name *args: mktarget_dirs
	odin test examples/{{name}}.odin -file -debug -microarch:native -show-timings -define:ODIN_TEST_THREADS=1 -out:target/debug/{{test_main_name}} {{args}}

# simple delete of all debug databases and executables in the target directory
[unix]
clean:
	rm -rf target
	just mktarget_dirs

# simple delete of all debug databases and executables in the target directory
[windows]
clean:
	-Remove-Item -Recurse -Force target
	just mktarget_dirs

# build an example with verbose diagnostics
diagnose name="smoke" *args: mktarget_dirs
	odin build examples/{{name}}.odin -file -debug -microarch:native -show-more-timings -show-debug-messages -show-timings -out:target/debug/{{name}}.exe {{args}}


# Static, not DLL: Odin runs C++ ctors (entry=mainCRTStartup) so the static archive links and
# self-contains into one exe (no dds.dll / VCOMP140.DLL to ship). Trade-off: DDS's DllMain
# auto-init does NOT run when statically linked -> consumers must call SetMaxThreads(0) once
# before use (see src/prelude.odin and example/main.odin).
# ---
# build the self-contained DDS static lib and stage it into ./lib
[unix]
build-lib: submodules
	make -C src
	# TODO: src/Makefile (Unix/macOS) not written yet. Model it on odin-yyjson's src/Makefile,
	# built from external/dds/src/Makefile_linux_static (and Makefile_Mac_*_static for darwin).
	# It must compile the DDS sources (2.9.1 code, pinned commit 7219c95) and stage lib/dds.a
	# (+ lib/darwin/dds.a on macOS), matching the paths src/prelude.odin expects.

# build the self-contained DDS static lib and stage it into ./lib
[windows]
build-lib: submodules
	cmd /c 'src\build.cmd lib external\dds'
	New-Item -ItemType Directory -Force lib | Out-Null
	cp external/dds/build/dds.lib lib/dds.lib


# Idempotent: a no-op (no network) once the submodule is present at the recorded commit.
# ---
# check out / update the external/dds git submodule
submodules:
	git submodule update --init --recursive


# bindgen names its output after the header stem (dll.h -> dll.odin), so it is renamed to
# dds.odin to match the package. Requires ../odin-c-bindgen.
# ---
# regenerate the Odin bindings from external/dds/include/dll.h
bindgen: submodules
	../odin-c-bindgen/bindgen.exe .
	mv -Force dll.odin dds.odin

