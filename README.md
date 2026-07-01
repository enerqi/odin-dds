# odin-dds

[Odin](http://odin-lang.org/) bindings for [DDS](https://github.com/dds-bridge/dds), Bo Haglund and Soren Hein's
double-dummy solver for the game of bridge.

A *double-dummy solver* computes the exact number of tricks each side can take on a given deal with all four hands
visible and optimal play from everyone. DDS is the de-facto standard engine behind bridge hand analysis, par-score and
par-contract calculation, and play analysis; it is fast, multi-threaded, and battle-tested.

The DDS C/C++ source is included as a git submodule under [`external/dds`](./external/dds) and is *not* modified — these
bindings wrap its public C ABI (`include/dll.h`).


## API structure

The bindings are a near 1-to-1 port, so the original [DDS interface
documentation](./external/dds/doc/dll-description.md) is easy to follow.

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

	deal: dds.Deal
	// ... fill in the deal ...
	fut: dds.Future_Tricks
	dds.SolveBoard(deal, -1, 3, 1, &fut, 0)
}
```

Skipping `SetMaxThreads` (or `SetResources`) means the first DDS call dereferences unsized state and crashes. See
[`examples/smoke.odin`](./examples/smoke.odin) for a runnable smoke test (`just run`).


## Version

| odin-dds tag | DDS version | notes                        |
| ------------ | ----------- | ---------------------------- |
| 2026-07      | 2.9.0       | Initial bindings             |


## Building the DDS static library

- The static library `dds.lib` for Windows is shipped with the bindings in [`./lib`](./lib).
- It is a **self-contained** static archive: no `dds.dll` and no `VCOMP140.DLL` (OpenMP) to ship — the whole solver
	folds into your one Odin executable. DDS runs its Windows-native (WinAPI) threading, so dropping OpenMP loses nothing
	here.
- The build script lives in [`src/build.cmd`](./src/build.cmd) (MSVC `cl` + `lib`). It compiles the DDS 2.9.0 sources
	from the `external/dds` submodule with `/MT` (static CRT, to match Odin's `libcmt` host) and archives them.

Rebuild it with:

```
just build-lib
```

This checks out the submodule if needed, runs `src/build.cmd lib external/dds`, and stages `dds.lib` into `./lib`.
`src/build.cmd` also has a `dll` mode (`src/build.cmd dll external/dds`) if you prefer a DLL — the script's header
comment weighs the static-vs-DLL trade-offs in depth.

> On a static Windows link there is no `DllMain` auto-init, so consumers must call `SetMaxThreads(0)` once (see above).
> The DLL build auto-initializes but then requires shipping `dds.dll` (+ `VCOMP140.DLL`) alongside the executable.


## Regenerating the bindings

`dds.odin` is generated from `external/dds/include/dll.h` by [odin-c-bindgen](https://github.com/karl-zylinski/odin-c-bindgen)
using [`bindgen.sjson`](./bindgen.sjson). Regenerate with:

```
just bindgen
```

Two `bindgen.sjson` details worth knowing:

- `clang_defines = { "bool" = "_Bool" }` — `dll.h` uses `bool` without including `<stdbool.h>`; libclang parses a `.h`
	as C, where `bool` is not a keyword pre-C23. `_Bool` is the 1-byte C99 builtin, matching the C++ `bool` in the
	compiled lib so struct layout is preserved.
- bindgen names its output after the header stem (`dll.h` → `dll.odin`), so `just bindgen` renames it to `dds.odin`.

Hand-written additions (the `foreign import` block, platform selection) live in [`src/prelude.odin`](./src/prelude.odin)
and are pasted near the top of the generated file.


## Development

Tasks are run with [just](https://just.systems/) (`just TASK`); the Windows shell is PowerShell.

- `just run [name]` — build and run an example (`examples/<name>.odin`, default `smoke`); e.g. `just run solve_board`
- `just lint` — type check + vet + strict style
- `just format` — `odinfmt -w .`
- `just test` — run tests
- `just build-lib` — (re)build and stage the DDS static lib
- `just bindgen` — regenerate the bindings
- `just submodules` — check out / update the `external/dds` submodule


## License

These bindings are provided under the terms in [`LICENSE`](./LICENSE). DDS itself is licensed under the Apache 2.0
license — see [`external/dds/LICENSE`](./external/dds/LICENSE).
