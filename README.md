# odin-dds

[Odin](http://odin-lang.org/) bindings for [DDS](https://github.com/dds-bridge/dds), Bo Haglund and Soren Hein's
double-dummy solver for the game of bridge.

A *double-dummy solver* computes the exact number of tricks each side can take on a given deal with all four hands
visible and optimal play from everyone. DDS is the de-facto standard engine behind bridge hand analysis, par-score and
par-contract calculation, and play analysis; it is fast, multi-threaded, and battle-tested.

The DDS C/C++ source is included as a git submodule under [`external/dds`](./external/dds) and is *not* modified — these
bindings wrap its public C ABI (`include/dll.h`).


## API structure

See [`docs/api.md`](./docs/api.md) for the idiomatic-Odin API guide — types, core functions, threading, and
memory lifecycle. The bindings are a near 1-to-1 port, so the original [DDS interface
documentation](https://github.com/dds-bridge/dds/blob/7219c95/doc/dll-description.md) also maps directly.

- Functions keep their C names: `SolveBoard`, `CalcDDtable`, `Par`, ... are called as `dds.SolveBoard`,
	`dds.CalcDDtable`, `dds.Par`.
- Struct/type names drop the `dd` prefix and are `Ada_Case` per Odin convention: C `struct deal` → `dds.Deal`,
	`struct ddTableResults` → `dds.Table_Results`, `struct futureTricks` → `dds.Future_Tricks`. (`struct DDSInfo` is
	renamed `dds.DDS_Info`.)
- The `#define` error/return codes are exposed as constants: `dds.RETURN_NO_FAULT`, `dds.RETURN_UNKNOWN_FAULT`, ...

### Initialization is required

DDS needs a one-time setup call before **any** other function — it sizes the per-thread transposition-table memory and
builds its constant lookup tables. When DDS is used as a *DLL* this happens automatically from `DllMain`, but these
bindings link a **static** library, which has no `DllMain`, so you must do it yourself:

```odin
package main

import dds ".."

main :: proc() {
	dds.SetMaxThreads(0) // 0 = let DDS pick the thread count from the core count. Call once, before anything else.
	defer dds.FreeMemory()

	deal: dds.Deal
	// ... fill in the deal ...
	fut: dds.Future_Tricks
	// target = TARGET_FIND_MAX (find the best), solutions = .All, mode = .Auto_Skip_Single.
	dds.SolveBoard(deal, dds.TARGET_FIND_MAX, .All, .Auto_Skip_Single, &fut)
}
```

Skipping `SetMaxThreads` (or `SetResources`) means the first DDS call dereferences unsized state and crashes. See
[`examples/smoke.odin`](./examples/smoke.odin) for a runnable smoke test (`just run`).


## Version

| odin-dds tag | DDS version           | notes                        |
| ------------ | --------------------- | ---------------------------- |
| 2026-07      | 2.9.1 code (`7219c95`) | Initial bindings             |

> DDS never tagged 2.9.1, so the `external/dds` submodule is pinned to commit **`7219c95`** — the
> code-complete 2.9.1 point on the flat-layout `include/`+`src/` tree (`DDS_VERSION` upstream is still
> `20900`; the version was never bumped). This gets the 2.9.1 fixes — rimmington's transposition-table
> memory-freeing fixes, `#include <stdbool.h>` in C mode, and the `SolveAllBoardsBin` entry point —
> without the later v3 refactor that moved `dll.h` to `library/src/api/`. Validated with DDS's own
> `dtest` (0 differences across solve/calc/play/par).


## Building the DDS static library

The pre-built static libraries are shipped with the bindings in [`./lib`](./lib):

| Platform | File | Built by |
| -------- | ---- | -------- |
| Windows | `lib/dds.lib` | [`src/build.cmd`](./src/build.cmd) (MSVC `cl` + `lib`) |
| Linux / BSD | `lib/dds.a` | [`src/Makefile`](./src/Makefile) (`g++` + `ar`) |
| macOS | `lib/darwin/dds.a` | [`src/Makefile`](./src/Makefile) (`clang++` + `ar`) |

All are **self-contained** static archives — the whole solver folds into your one Odin executable with no shared libraries to ship. Each platform uses its native threading: WinAPI on Windows, GCD on macOS, STL on Linux (no OpenMP dependency). The Odin bindings pull in `libstdc++` and `libpthread` on Linux/BSD automatically via `foreign import`.

Rebuild with:

```
just build-lib
```

On Windows this runs `src/build.cmd lib external/dds` (requires MSVC; auto-detected via `vswhere`) and stages `lib/dds.lib`. On Unix it runs `make -C src` and stages `lib/dds.a` or `lib/darwin/dds.a`. The submodule is checked out if needed.

`src/build.cmd` also has a `dll` mode (`src/build.cmd dll external/dds`) if you prefer a DLL on Windows — the script's header comment weighs the static-vs-DLL trade-offs in depth.

> Static linking has no `DllMain`/constructor auto-init, so consumers must call `SetMaxThreads(0)` once before any other DDS call (see above). The DLL build auto-initializes but then requires shipping `dds.dll` (+ `VCOMP140.DLL`) alongside the executable.


## Regenerating the bindings

`dds.odin` is generated from `external/dds/include/dll.h` by [odin-c-bindgen](https://github.com/karl-zylinski/odin-c-bindgen)
using [`bindgen.sjson`](./bindgen.sjson). Regenerate with:

```
just bindgen
```

A `bindgen.sjson` detail worth knowing: bindgen names its output after the header stem (`dll.h` → `dll.odin`),
so `just bindgen` renames it to `dds.odin`.

> Historical note: DDS 2.9.0's `dll.h` used `bool` without including `<stdbool.h>`, so `bool` was undefined
> when libclang parsed the header as C — the bindings needed a `clang_defines = { "bool" = "_Bool" }` override.
> The 2.9.1 pin (`7219c95`) adds that include upstream, so `bool` resolves on its own and the override is gone.

Hand-written additions (the `foreign import` block, platform selection) live in [`src/prelude.odin`](./src/prelude.odin)
and are pasted near the top of the generated file.


## Development

Tasks are run with [just](https://just.systems/) (`just TASK`); the Windows shell is PowerShell.

- `just run [name]` — build and run an example (`examples/<name>.odin`, default `smoke`); e.g. `just run solve_board`
- `just lint` — type check + vet + strict style
- `just format` — `odinfmt -w .`
- `just test` — run all tests (they live as `@(test)` procs inside `examples/*.odin`); `just test1 <name>` runs one example's tests
- `just build-lib` — (re)build and stage the DDS static lib
- `just bindgen` — regenerate the bindings
- `just submodules` — check out / update the `external/dds` submodule


## License

These bindings are provided under the terms in [`LICENSE`](./LICENSE). DDS itself is licensed under the Apache 2.0
license — see [`external/dds/LICENSE`](./external/dds/LICENSE).
