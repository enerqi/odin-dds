set windows-shell := ["powershell", "-NoLogo", "-Command"]
set shell := ["bash", "-c"]

main_name := "main.exe"
test_main_name := "test-main.exe"

# SKELETON: name your extra collection (the `xyz:` prefix in `import "xyz:pkg"`) and where it lives.
# collection_path is read from an env var so the absolute path stays out of git; rename both to suit.
collection_name := "xyz"
collection_path := env_var_or_default("XYZ_HOME", "")

# odinfmt select files
format:
	odinfmt -w dds.odin
	odinfmt -w example/main.odin


# lint checks for style and potential bugs. Accepts extra args like `--show-timings`as needed
lint *args:
	odin check . -vet -vet-cast -strict-style -no-entry-point {{args}}
	odin check example -vet -vet-cast -strict-style -no-entry-point {{args}}


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

# run with debug build (-keep-executable so `rerun_debug` can skip recompiling)
run_debug *args: mktarget_dirs
	odin run example -debug -microarch:native -show-timings -keep-executable -out:target/debug/{{main_name}} {{args}}

alias run := run_debug

# run with debug and optimizations (-keep-executable so `rerun_fastdebug` can skip recompiling)
run_fastdebug *args: mktarget_dirs
	odin run example -debug -o:speed -microarch:native -show-timings -keep-executable -out:target/fastdebug/{{main_name}} {{args}}

# run with optimizations (-keep-executable so `rerun_release` can skip recompiling)
run_release *args: mktarget_dirs
	odin run example -o:speed -microarch:native -show-timings -keep-executable -out:target/release/{{main_name}} {{args}}

# re-run the last debug binary WITHOUT recompiling (Odin has no build cache, so a plain `run` always
# rebuilds). Requires a prior `run_debug`/`run` build.
rerun_debug *args:
	./target/debug/{{main_name}} {{args}}

alias rerun := rerun_debug

# re-run the last fastdebug binary without recompiling. Requires a prior `run_fastdebug` build.
rerun_fastdebug *args:
	./target/fastdebug/{{main_name}} {{args}}

# re-run the last release binary without recompiling. Requires a prior `run_release` build.
rerun_release *args:
	./target/release/{{main_name}} {{args}}

# run all tests
test *args: mktarget_dirs
	odin test . -debug -file -microarch:native -show-timings -out:target/debug/{{test_main_name}} {{args}}

# run one named test
test1 name *args: mktarget_dirs
	odin test . -debug -file -microarch:native -show-timings -test-name:{{name}} -out:target/debug/{{test_main_name}} {{args}}

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

# build with some verbose diagnostics
diagnose *args: mktarget_dirs
	odin build example -debug -microarch:native -show-more-timings -show-debug-messages -show-timings -out:target/debug/{{main_name}} {{args}}


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
	# It must compile the DDS 2.9.0 sources and stage lib/dds.a (+ lib/darwin/dds.a on macOS),
	# matching the paths src/prelude.odin expects.

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

