@echo off
setlocal
rem ===========================================================================
rem  build-v3.cmd - minimal Bazel wrapper for DDS 3.0.0 static lib, with the
rem  cl flags overridden to match the 2.9.0 build.cmd intent.
rem
rem  Usage:  build-v3.cmd [dds-dir]            (default: ".", the current dir)
rem  Relocatable like build.cmd: the script does NOT use its own location. It
rem  pushd's into <dds-dir> first because Bazel locates the workspace (MODULE.
rem  bazel) from the current directory upward - run outside the tree and Bazel
rem  errors with "not in a Bazel workspace".
rem
rem  Output:  <dds-dir>\bazel-bin\library\src\dds.lib   (`bazel cquery` if unsure)
rem  Run from a VS x64 dev prompt, or with cl/Bazel otherwise on PATH.
rem
rem  Bazel windows defaults already give: /O2 (-c opt), /std:c++20, /W4 /WX
rem  /permissive-, /EHsc. So we only override the rest of build.cmd's intent.
rem
rem  NOTE on threading: v3 reworked the threading layer - System's dispatch
rem  callbacks were removed (system/system.cpp) and the DDS_THREADS_* macros now
rem  mostly drive capability DETECTION. Passing these defines reproduces 2.9.0's
rem  configured set, but VERIFY at runtime (SetMaxThreads + solve many boards,
rem  watch CPU) that v3 actually parallelizes before relying on it.
rem
rem  We deliberately DROP /openmp (and the OPENMP system): /openmp pulls in
rem  vcomp140.dll, a runtime DLL dep that defeats the self-contained /MT static
rem  build. WINAPI/STL/STLIMPL/PPLIMPL are all self-contained and link into the
rem  static CRT cleanly. Add DDS_THREADS_OPENMP + /openmp back only if you
rem  measure it faster AND accept shipping vcomp140.dll.
rem ===========================================================================

rem --- DDS root (1st arg, default current dir), resolved to a full path so this
rem     works from anywhere. We pushd into it for Bazel's workspace detection. ---
set "DDS_DIR=%~1"
if not defined DDS_DIR set "DDS_DIR=."
for %%I in ("%DDS_DIR%") do set "DDS_DIR=%%~fI"
if not exist "%DDS_DIR%\MODULE.bazel" (
    echo [build-v3] No Bazel workspace at "%DDS_DIR%" (MODULE.bazel missing^).
    exit /b 1
)

rem --- optional AVX2 (OFF by default, like build.cmd: DDS is scalar, ~0-3% and
rem     drops pre-2013 CPUs). Opt in:  set DDS_ARCH=/arch:AVX2  before running. ---
set ARCH=
if defined DDS_ARCH set ARCH=--copt=%DDS_ARCH%

pushd "%DDS_DIR%"
bazel build -c opt //library/src:dds ^
    --features=msvc_static_runtime ^
    --copt=/Gy ^
    --copt=/DDDS_THREADS_WINAPI ^
    --copt=/DDDS_THREADS_STL ^
    --copt=/DDDS_THREADS_STLIMPL ^
    --copt=/DDDS_THREADS_PPLIMPL ^
    %ARCH% ^
    --subcommands
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%

rem  --features=msvc_static_runtime -> /MT (LIBCMT), matches the Odin host that
rem  links /defaultlib:libcmt. Do NOT use /MD here (two CRTs / two heaps).

rem  DLL only (v3 Bazel targets a static lib; there is no DLL target):
rem    --linkopt=/LTCG ^
rem    --linkopt=/OPT:REF ^
rem    --linkopt=/OPT:ICF ^
