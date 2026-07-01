@echo off
setlocal enabledelayedexpansion
rem ===========================================================================
rem  build.cmd - one-shot DDS build (MSVC cl + lib/link)
rem
rem  Usage:  build.cmd [lib|dll] [dds-dir]    (defaults: lib  .)
rem      lib  -> static library      <dds-dir>\build\dds.lib
rem      dll  -> shared library      <dds-dir>\build\dds.dll (+ import lib dds.lib)
rem
rem  This script is relocatable: it does NOT use its own location. Point it at a
rem  DDS checkout via the 2nd arg (default ".", the current directory). Sources
rem  are read from <dds-dir>\src and output goes to <dds-dir>\build. So if this
rem  file lives at the dds root and you run it from there, no args are needed.
rem    e.g.  build.cmd dll  C:\code\dds      or just  build.cmd  (from dds root)
rem
rem  Translated from Makefiles/Makefile_Visual. Both modes compile the same
rem  objects with the same multithreading support; only the final step differs
rem  (lib archives them, dll links them with Exports.def + the version resource).
rem
rem  Run from a "x64 Native Tools" VS prompt, OR just run this file directly:
rem  it auto-locates VS via vswhere and calls vcvars64.bat if cl is not on PATH.
rem ===========================================================================
rem
rem  ----------------- WHICH ARTIFACT: static .lib vs .dll --------------------
rem  Context: x64, DDS is a coarse-grained solver (each API call does ms-seconds
rem  of work), typically consumed here from Odin via lld-link.
rem
rem  PERFORMANCE - effectively a tie, marginal edge to the DLL.
rem    * DLL boundary calls take one indirect hop through the import table; that
rem      is a single pointer deref per SolveBoard, lost in the noise of a solve.
rem    * The DLL is built /GL + LTCG, so DDS is whole-program optimized INTERNALLY.
rem      The static .lib drops /GL (so foreign linkers can read it), thus loses
rem      cross-translation-unit inlining inside DDS. Net: indistinguishable.
rem    * Want max static perf for an MSVC-only consumer? Build a second /GL .lib;
rem      keep the plain one for Odin/lld-link.
rem
rem  PORTABILITY - DLL wins at the boundary, static wins at deploy.
rem    * .lib is MSVC COFF: only MSVC-family linkers (link.exe, lld-link) consume
rem      it - NOT MinGW/GCC; x64-locked. Upside: folds into one self-contained exe.
rem    * .dll exposes only the C ABI -> callable by anything that speaks C (MinGW,
rem      GCC, Python ctypes, C#, LoadLibrary, ...). Cost: 2-file deploy + runtime
rem      dep (vcomp140.dll for OpenMP; CRT is static via /MT, so no UCRT dep).
rem
rem  LONGEVITY - DLL wins.
rem    * .lib is tied to the MSVC object/ABI, must be relinked into every consumer
rem      and rebuilt on major toolchain bumps. A /GL .lib is fragile (LTCG objects
rem      are not guaranteed readable across cl versions); plain COFF lasts longer.
rem    * .dll has /GL fully resolved at link time -> zero toolchain coupling. The C
rem      ABI boundary is the most stable contract Windows offers: a DLL built today
rem      is callable for decades, and DDS can be updated WITHOUT relinking the app.
rem
rem  CRT: both use /MT -> the static CRT (LIBCMT) is baked in; no UCRT/vcruntime
rem  runtime dependency (the DLL still needs vcomp140.dll for OpenMP). /MT is not
rem  just "standalone" here - it is REQUIRED to match the Odin host, which links
rem  the static CRT (/defaultlib:libcmt). See the CRT note below.
rem
rem  VERDICT for "ship one Odin binary": static .lib (the default) - self-contained
rem  exe, lld-link consumes it cleanly, accept the tiny internal-inlining loss.
rem  Choose the DLL to update DDS independently, reuse it across languages, or
rem  maximize future-proofing.
rem
rem  DDS-SPECIFIC INIT CAVEAT (static lib only): DDS auto-initializes from its
rem  DllMain (DLL_PROCESS_ATTACH -> SetMaxThreads(0), see src/dds.cpp), which sizes
rem  per-thread transposition-table memory and builds constant tables. That entry
rem  only fires for the DLL. When STATICALLY linked there is no DllMain (and MSVC
rem  has no __attribute__((constructor)) path), so nothing auto-inits -> the FIRST
rem  DDS call dereferences unsized state and crashes. Static consumers MUST call
rem  SetMaxThreads(0) (or SetResources) once at startup before any other DDS call.
rem  (C++ global ctors like `sysdep` DO still run - that is CRT init, not DllMain.)
rem ===========================================================================

rem --- mode --------------------------------------------------------------------
set "MODE=%~1"
if not defined MODE set "MODE=lib"
if /i "%MODE%"=="lib" goto mode_ok
if /i "%MODE%"=="dll" goto mode_ok
echo [build] Unknown mode "%MODE%". Use: build.cmd [lib^|dll] [dds-dir]
exit /b 1
:mode_ok

rem --- locations --------------------------------------------------------------
rem 2nd arg = DDS root (default current dir). Resolved to a full path so the
rem build works regardless of where this script physically lives.
set "DDS_DIR=%~2"
if not defined DDS_DIR set "DDS_DIR=."
for %%I in ("%DDS_DIR%") do set "DDS_DIR=%%~fI"
set "SRC_DIR=%DDS_DIR%\src"
if not exist "%SRC_DIR%\dds.cpp" (
    echo [build] No DDS sources at "%SRC_DIR%". Pass the dds root as 2nd arg.
    exit /b 1
)
set "BUILD_DIR=%DDS_DIR%\build"
set "OBJ_DIR=%BUILD_DIR%\obj"
set "OUT_LIB=%BUILD_DIR%\dds.lib"
set "OUT_DLL=%BUILD_DIR%\dds.dll"
set "RES_FILE=%OBJ_DIR%\dds.res"

rem --- make sure cl is on PATH, else find VS and load the x64 dev env ----------
where cl >nul 2>nul
if %errorlevel%==0 goto have_cl

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
    echo [build] cl not on PATH and vswhere not found.
    echo [build] Open a "x64 Native Tools Command Prompt for VS" and re-run.
    exit /b 1
)
rem -prerelease so VS 2026 / preview channels are found too.
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSINSTALL=%%i"
if not defined VSINSTALL (
    echo [build] No VS install with C++ tools found via vswhere.
    exit /b 1
)
if not exist "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" (
    echo [build] vcvars64.bat missing under "%VSINSTALL%".
    exit /b 1
)
echo [build] Loading x64 toolchain from "%VSINSTALL%"
call "%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat" >nul
where cl >nul 2>nul || (echo [build] cl still not on PATH after vcvars64. & exit /b 1)
:have_cl

rem --- compiler configuration -------------------------------------------------
rem Threading systems compiled in (single-threading always available). Boost and
rem GCD dropped: Boost needs author-specific include paths, GCD is not Windows.
rem OpenMP is DLL-only: /openmp adds a load-time dependency on VCOMP140.DLL, which
rem defeats the static lib's self-contained-exe goal. DDS reports threading=1
rem (Windows native / WinAPI) as the active system anyway, so OpenMP is unused at
rem runtime here. The static .lib therefore drops DDDS_THREADS_OPENMP + /openmp
rem (see also build-v3.cmd, which drops it for the same reason).
set "THREADING=/DDDS_THREADS_WINAPI /DDDS_THREADS_STL /DDDS_THREADS_STLIMPL /DDDS_THREADS_PPLIMPL"
set "OMP_FLAG="
if /i "%MODE%"=="dll" set "THREADING=%THREADING% /DDDS_THREADS_OPENMP"
if /i "%MODE%"=="dll" set "OMP_FLAG=/openmp"

rem Optional behaviour toggles (see debug.h). Left empty as in the makefile.
set "DDS_BEHAVIOR="

rem Note: DDS has no __declspec export macros - the DLL's exported symbols come
rem entirely from Exports.def at link time, so no extra compile define is needed.

rem Whole-program optimisation (/GL) is used ONLY for the DLL, where MSVC's own
rem link /LTCG consumes it. /GL objects hold MSVC's proprietary IL, NOT machine
rem code and NOT LLVM bitcode - so a foreign linker (lld-link, e.g. an Odin build,
rem even with `odin build -lto`) cannot read or trim them; only MSVC link /LTCG
rem can. Therefore the static-lib path omits /GL and emits real COFF machine code,
rem which any linker links and dead-strips (archive member pull + /OPT:REF) the
rem normal way. (This also keeps the .lib a few hundred KB instead of ~40 MB.)
set "GL_FLAG="
if /i "%MODE%"=="dll" set "GL_FLAG=/GL"

rem C runtime: /MT = static CRT (LIBCMT). REQUIRED to match the Odin host, NOT a
rem standalone-build preference. Odin's Windows backend emits /defaultlib:libcmt
rem (the STATIC CRT) for every executable - verified in Odin src/linker.cpp:
rem   no_crt ? " /nodefaultlib" : " /defaultlib:libcmt"
rem - and Odin offers no flag to select the dynamic CRT (only -no-crt to drop it).
rem MSVC requires every object in one link use the same /M flag, so the static
rem .lib must be /MT to match libcmt. /MD (dynamic MSVCRT) would mismatch -> LNK4098
rem + two CRT copies / two heaps -> heap corruption when the host frees memory DDS
rem allocated. This holds for MS link.exe, lld-link, and rad-link alike (all
rem MSVC-family COFF linkers that honor the embedded /defaultlib directive).
set "CRT=/MT"

rem SIMD: DDS has no intrinsics/popcount/vectorizable hot loops - it is scalar,
rem branchy alpha-beta search. /arch:AVX2 buys ~0-3% here and drops support for
rem pre-2013 (pre-Haswell) CPUs, so it is OFF by default. Opt in for a local CPU:
rem   set "ARCH=/arch:AVX2"   (export DDS_ARCH=/arch:AVX2 before calling, below)
set "ARCH=%DDS_ARCH%"

rem Modern release flags. /O2 implies /Oi/Ot. /Oy and /Ox from the makefile are
rem x86-era and dropped for x64. /EHsc is the standard C++ exception model.
rem /MP compiles the translation units in parallel.
rem /Gy puts each function in its own COMDAT so a foreign linker's /OPT:REF can
rem dead-strip unused functions individually (not just whole .obj members) - this
rem sharpens the "trim the static lib" goal for Odin/lld-link consumers.
rem /wd4996 + _CRT_SECURE_NO_WARNINGS silence the C4996 "unsafe" deprecation
rem warnings on strcpy/sprintf/strcat etc. that DDS uses throughout.
rem /wd4267 silences C4267 size_t->unsigned narrowing in TransTableL.cpp.
set "COMPILE_FLAGS=/nologo /c /MP %CRT% /EHsc /std:c++17 /O2 /Gy %GL_FLAG% %ARCH% /W3 /wd4996 /wd4267 /D_CRT_SECURE_NO_WARNINGS /DWIN32 /D_WINDOWS %OMP_FLAG% %DDS_BEHAVIOR% %THREADING%"

rem To mirror the makefile's aggressive warnings instead, swap /W3 above for:
rem   /Wall /WX /wd4365 /wd4464 /wd4514 /wd4555 /wd4571 /wd4623 /wd4625
rem   /wd4626 /wd4668 /wd4710 /wd4711 /wd4774 /wd4820 /wd4996 /wd5026 /wd5027
rem (Expect new MSVC warnings under /Wall /WX on a 2026 toolchain.)

rem --- source list (kept in sync with Makefiles/sources.txt) ------------------
set "SOURCES=dds.cpp dump.cpp ABsearch.cpp ABstats.cpp CalcTables.cpp DealerPar.cpp File.cpp Init.cpp LaterTricks.cpp Memory.cpp Moves.cpp Par.cpp PlayAnalyser.cpp PBN.cpp QuickTricks.cpp Scheduler.cpp SolveBoard.cpp SolverIF.cpp System.cpp ThreadMgr.cpp Timer.cpp TimerGroup.cpp TimerList.cpp TimeStat.cpp TimeStatList.cpp TransTableS.cpp TransTableL.cpp"

rem --- build ------------------------------------------------------------------
if not exist "%OBJ_DIR%" mkdir "%OBJ_DIR%"

pushd "%SRC_DIR%"

echo [build] Mode: %MODE%
echo [build] Compiling %SRC_DIR%\*.cpp -^> %OBJ_DIR%
cl %COMPILE_FLAGS% /Fo"%OBJ_DIR%\\" %SOURCES%
if errorlevel 1 (
    echo [build] Compilation FAILED.
    popd & exit /b 1
)

if /i "%MODE%"=="dll" goto link_dll

rem --- static library ---------------------------------------------------------
echo [build] Archiving -^> %OUT_LIB%
rem Plain archive: objects are real COFF (no /GL), so no /LTCG. Foreign-linker
rem friendly (Odin etc.) and dead-strippable by any linker.
lib /nologo /OUT:"%OUT_LIB%" "%OBJ_DIR%\*.obj"
if errorlevel 1 (
    echo [build] lib FAILED.
    popd & exit /b 1
)
popd
echo [build] Removing intermediate objects %OBJ_DIR%
rmdir /s /q "%OBJ_DIR%"
echo [build] Done: %OUT_LIB%
endlocal
exit /b 0

rem --- shared library (DLL) ---------------------------------------------------
:link_dll
echo [build] Compiling version resource dds.rc -^> %RES_FILE%
rc /nologo /fo "%RES_FILE%" dds.rc
if errorlevel 1 (
    echo [build] rc FAILED. (You can drop the .res from the link line if rc is
    echo [build]  unavailable - it only carries DLL version metadata.^)
    popd & exit /b 1
)

echo [build] Linking -^> %OUT_DLL%
rem /LTCG matches the /GL objects. Exports.def names the public API symbols.
rem /IMPLIB writes the import library next to the DLL (named dds.lib).
rem /OPT:REF,ICF strips unused /Gy COMDATs and folds identical ones.
link /nologo /DLL /LTCG /OPT:REF /OPT:ICF /OUT:"%OUT_DLL%" /IMPLIB:"%OUT_LIB%" ^
    /DEF:Exports.def "%OBJ_DIR%\*.obj" "%RES_FILE%"
if errorlevel 1 (
    echo [build] link FAILED.
    popd & exit /b 1
)
popd
echo [build] Removing intermediate objects %OBJ_DIR%
rmdir /s /q "%OBJ_DIR%"
echo [build] Done: %OUT_DLL% (+ import lib %OUT_LIB%)
endlocal
exit /b 0

rem ===========================================================================
rem  Optional cleanup (uncomment to use as: build.cmd then these by hand)
rem ---------------------------------------------------------------------------
rem :clean
rem   if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
rem ===========================================================================
