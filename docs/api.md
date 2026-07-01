# odin-dds API reference

Idiomatic-Odin guide to the [DDS](https://github.com/dds-bridge/dds) double-dummy solver as exposed by
these bindings. It covers the types, the core functions, threading, and memory lifecycle.

This is a **curated** reference, not an exhaustive port. For the full field-by-field description of every
struct and function, see the original DDS interface document,
[`external/dds/doc/dll-description.md`](../external/dds/doc/dll-description.md) — the bindings are a near
1:1 name-for-name port, so it maps directly (see [Naming](#naming)). Every function below has a runnable
example under [`examples/`](../examples); those are the authoritative usage samples and double as the test
suite (`just test`).

> **Which API is this?** DDS has a legacy C ABI (`external/dds/include/dll.h`) and, as of v3.0.0, a newer
> C++ `SolverContext` API. **These bindings wrap the legacy C ABI.** The threading model described here is
> the C-ABI one (DDS owns a global worker pool); the v3 C++ model inverts that (see
> [Legacy vs modern](#legacy-vs-modern-threading)).

---

## Naming

- **Functions** keep their C names: `dds.SolveBoard`, `dds.CalcDDtable`, `dds.Par`, …
- **Types** drop the `dd` prefix and are `Ada_Case`: C `struct deal` → `dds.Deal`, `struct ddTableResults`
  → `dds.Table_Results`, `struct futureTricks` → `dds.Future_Tricks`, `struct DDSInfo` → `dds.DDS_Info`.
- **Integer-coded arguments become enums / `bit_set` / enumerated arrays** (below). All enum/`bit_set`
  types are `i32`/`u32`-backed to preserve the exact C struct layout and return ABI. These wrappers are
  wired on via `bindgen.sjson`, so they survive `just bindgen`.

---

## Types — C encodings as Odin types

The C API speaks in `int` codes; the bindings replace them with named types. Summary:

| DDS C encoding                     | Odin type            | Notes |
| ---------------------------------- | -------------------- | ----- |
| Suit `int` 0..3                    | `dds.Suit`           | `.Spades .Hearts .Diamonds .Clubs` |
| Strain `int` 0..4 (suit + NT)      | `dds.Strain`         | `.Spades … .Clubs .NT` |
| Hand `int` 0..3                    | `dds.Hand`           | `.North .East .South .West` |
| Side `int` 0..1                    | `dds.Side`           | `.NS .EW` |
| Vulnerability `int`                | `dds.Vulnerability`  | `.None .Both .NS .EW` |
| Holding `unsigned` bitmask         | `dds.Holding`        | `bit_set[Rank; u32]` — set of ranks in one suit |
| Return code `int`                  | `dds.Return_Code`    | `.NO_FAULT` (== 1) is success; see [Return codes](#return-codes) |
| `SolveBoard` `solutions` `int`     | `dds.Solutions`      | `.One .All_Optimal .All` |
| `SolveBoard` `mode` `int`          | `dds.Solve_Mode`     | `.Auto_Skip_Single .Auto .Reuse` |
| threading system `int`             | `dds.Threading`      | `.None .WinAPI .OpenMP …` |

Two `int` arguments stay plain `i32` because they are genuinely numbers, not categories, with a sentinel:

- `SolveBoard` **`target`** — a trick count `0..13`, or `dds.TARGET_FIND_MAX` (`-1`) = "find the maximum".
- `CalcAllTables` **`mode`** — a `Vulnerability` value, or `dds.NO_PAR_CALC` (`-1`) = "skip the par calc".

### Holding — a suit as a bit_set

A `Holding` is the set of ranks held in one suit. Build it from `dds.Rank` members:

```odin
spades := dds.Holding{.Ace, .King, .Queen, ._9, ._4, ._2} // AKQ942
```

`Rank` bit 2 is the deuce and bit 14 is the ace (bits 0/1 always zero — the DDS mask convention), but you
never touch bits: use `._2 … ._9, .Ten, .Jack, .Queen, .King, .Ace`.

### Enumerated arrays make the tables self-documenting

Where C uses `remainCards[4][4]` or `resTable[5][4]` with index conventions you must memorize, the bindings
use enumerated arrays so the indices *are* the enums:

```odin
deal.cards[.North][.Spades] = spades          // [Hand][Suit]Holding
tricks := res.resTable[.NT][.North]           // [Strain][Hand]i32
```

> **Gotcha — `denom` ordering.** `Contract_Type.denom` uses a *different* order than `Suit`/`Strain`
> (NT is `0` here, not `4`); it has its own enum, `dds.Contract_Denom`, to stop the two being mixed up.
> This only surfaces in the structured par results (`SidesParBin` / `DealerParBin`).

### Deal types — `Deal` vs `Table_Deal`, and the PBN twins

Two deal structs, because the two kinds of query need different inputs:

- **`dds.Deal`** — for `SolveBoard` / `AnalysePlay*`: the cards **plus** `trump` (`Strain`), `first` (`Hand`
  on lead), and any `currentTrickSuit`/`currentTrickRank` already played. A *position*.
- **`dds.Table_Deal`** — for `CalcDDtable` / par: just `cards` (`[Hand][Suit]Holding`). No trump/lead,
  since it evaluates every strain and declarer.

**Every core function has a binary form and a `*PBN` twin** (`SolveBoard`/`SolveBoardPBN`,
`CalcDDtable`/`CalcDDtablePBN`, `CalcPar`/`CalcParPBN`, `AnalysePlayBin`/`AnalysePlayPBN`, …). The PBN twin
takes the deal as a **PBN string** instead of `Holding` bit_sets — a leading seat tag then the four hands
clockwise as `spades.hearts.diamonds.clubs`:

```
N:T5.K4.652.A98542 K6.QJT976.QT7.Q6 432.A.AKJ93.JT73 AQJ987.8532.84.K
```

Use the PBN form when your deals already arrive as text. The PBN deal fields are fixed `[80]i8` char
buffers; the examples fill them with a small `hands.set_chars` helper — see
[`examples/hands/hands.odin`](../examples/hands/hands.odin).

---

## Initialization is required

DDS needs one setup call before **any** other function — it sizes the per-thread transposition-table (TT)
memory and builds constant lookup tables. As a *DLL* this happens automatically from `DllMain`; these
bindings link a **static** library with no `DllMain`, so you must do it yourself, once, at startup:

```odin
dds.SetMaxThreads(0) // 0 = pick the thread count from the core count
```

Skipping it means the first DDS call dereferences unsized state and crashes. `SetResources` (below) is the
fuller alternative. See [`examples/smoke.odin`](../examples/smoke.odin).

---

## Core functions

Idiomatic signatures (defaulted trailing args shown). Each links its worked example.

### Single board — `SolveBoard`
"Best card(s) for the hand on lead, and the tricks they make, from this exact position."

```odin
SolveBoard :: proc(dl: Deal, target: i32, solutions: Solutions, mode: Solve_Mode,
                   futp: ^Future_Tricks, threadIndex: i32 = 0) -> Return_Code
```
```odin
fut: dds.Future_Tricks
dds.SolveBoard(dl, dds.TARGET_FIND_MAX, .All, .Auto_Skip_Single, &fut)
// fut.cards entries; fut.score[0] is the max tricks, fut.suit[i]/rank[i]/equals[i] the cards.
```
→ [`solve_board.odin`](../examples/solve_board.odin), [`solve_board_pbn.odin`](../examples/solve_board_pbn.odin)

### Full double-dummy table — `CalcDDtable`
"Tricks for all 5 strains × 4 declarers at once" — faster than 20 `SolveBoard`s (shares work across strains).

```odin
CalcDDtable :: proc(tableDeal: Table_Deal, tablep: ^Table_Results) -> Return_Code
```
```odin
res: dds.Table_Results
dds.CalcDDtable(td, &res)
n := res.resTable[.NT][.North]
```
→ [`calc_ddtable.odin`](../examples/calc_ddtable.odin), [`calc_ddtable_pbn.odin`](../examples/calc_ddtable_pbn.odin)

### Par — `Par`, `CalcPar`, `SidesPar`, `DealerPar`
The objective "what should this board score with perfect bidding". `Par` takes a table you already computed;
`CalcPar` / `CalcParPBN` fuse `CalcDDtable` + par in one call. `SidesPar`/`DealerPar` resolve the rare cases
where par depends on who bids first (`SidesPar` returns one result per side; `DealerPar` for a specific
dealer). The `*Bin` variants — `SidesParBin`, `DealerParBin` — return **structured** contracts
(`Par_Results_Master`, `Contract_Type` fields) instead of text, for programmatic use;
`ConvertToSidesTextFormat` / `ConvertToDealerTextFormat` render those structs back to display text.

```odin
Par :: proc(tablep: ^Table_Results, presp: ^Par_Results, vulnerable: Vulnerability) -> Return_Code
```
→ [`par.odin`](../examples/par.odin), [`calc_par.odin`](../examples/calc_par.odin),
[`sides_par.odin`](../examples/sides_par.odin), [`dealer_par.odin`](../examples/dealer_par.odin),
[`dealer_par_bin.odin`](../examples/dealer_par_bin.odin)

### Play analysis — `AnalysePlay*`
Replays an actual card sequence and reports the DD trick total after each card — a drop marks a card that
cost a trick.

→ [`analyse_play_bin.odin`](../examples/analyse_play_bin.odin), [`analyse_play_pbn.odin`](../examples/analyse_play_pbn.odin)

### Batched forms — solve many deals in one call
`SolveAllBoards` / `SolveAllBoardsBin`, `SolveAllChunks*`, `CalcAllTables*`, `AnalyseAllPlays*` take up to
`dds.MAXNOOFBOARDS` (**200**) deals and solve them **in parallel across DDS's own threads** (see below).
Prefer these to a hand loop when you have many deals.

```odin
bo: dds.Boards_Pbn
bo.noOfBoards = i32(n)                  // <= 200
// ... fill bo.deals[i], bo.target[i], bo.solutions[i], bo.mode[i] ...
solved: dds.Solved_Boards
dds.SolveAllBoards(&bo, &solved)        // DDS fans out internally
```

`SolveAllBoards` takes PBN input (`Boards_Pbn`); **`SolveAllBoardsBin`** is its binary-input twin (takes
`Boards`, whose deals hold `Holding` bit_sets) — added in DDS 2.9.1 "for symmetry" with the PBN form. Note
`SolveAllBoards` fixes `chunkSize` internally, whereas the `SolveAllChunks*` variants expose it.

→ [`solve_all_boards.odin`](../examples/solve_all_boards.odin), [`solve_all_chunks.odin`](../examples/solve_all_chunks.odin),
[`calc_all_tables.odin`](../examples/calc_all_tables.odin), [`analyse_all_plays_bin.odin`](../examples/analyse_all_plays_bin.odin)

---

## Multi-threading

The most common confusion: **you rarely thread anything yourself — DDS does the parallelism internally.**
"Threading" in this API spans two separate things.

### 1. DDS's internal worker pool — the default

The **batched** functions — `SolveAllBoards`/`SolveAllBoardsBin`, `SolveAllChunksBin/PBN`,
`CalcAllTables/PBN`, `AnalyseAllPlays*` — split their boards across a pool of worker threads **inside DDS**. `CalcDDtable`
similarly parallelizes per strain. You hand DDS a batch; it fans out; you get results back. **No threads in
your code.** From `dll-description.md`:

> "Solving hands can be done much more quickly using one of the multi-thread alternatives for calling
> SolveBoard. Then a number of hands are grouped for a single call to one of the functions `SolveAllBoards`,
> `SolveAllChunksBin` and `SolveAllChunksPBN`. The hands are then solved in parallel using the available
> threads."

The init calls **do not make you multi-threaded** — they *configure DDS's pool*:

- **`SetMaxThreads(userThreads := 0)`** — the required one-time init. `0` = DDS sizes the pool from cores +
  free memory. This allocates the per-thread TT memory the workers use. On Windows it auto-tunes; on
  Linux/macOS you should always call it (with `0`).
- **`SetResources(maxMemoryMB, maxThreads := 0)`** — fuller alternative to `SetMaxThreads`: also caps total
  TT memory. `SetResources(0)` = auto memory + auto threads.
- **`SetThreading(code: Threading) -> Return_Code`** — pick which backend runs the pool. Returns
  `.THREAD_MISSING` if that backend wasn't compiled in (then DDS keeps its current one). **This project's
  static lib is built with WinAPI/STL/STLIMPL/PPLIMPL — no OpenMP** (see `src/build.cmd`), so `.WinAPI` is
  the effective default on Windows and there is nothing to configure for normal use.

So the everyday recipe is just:

```odin
dds.SetMaxThreads(0)      // once, at startup
// ... use the batch functions; DDS threads internally ...
```

→ [`threading.odin`](../examples/threading.odin) shows `SetResources` + `SetThreading` + reading back the
config via `GetDDSInfo`.

### 2. Your own threads calling single-board functions — advanced, opt-in

`SolveBoard`, `SolveBoardPBN`, and `AnalysePlay*` are **thread-safe** and take a `threadIndex` / `thrId`
argument. This is the **only** reason to run your own threads: when you'd rather parallelize many
*independent single-board* solves from your own thread pool than batch them.

> "The basic functions `SolveBoard` and `SolveBoardPBN` each solve a single hand and are thread-safe, making
> it possible to use them for solving several hands in parallel."

The contract: each of your threads calls with a **distinct** `threadIndex` in `0 ..< noOfThreads` (the pool
size `SetMaxThreads` established), so each uses its own pre-allocated TT-memory slot. Reusing an index
across concurrent calls corrupts that slot.

```odin
// Pseudocode: N worker threads, each owning one DDS memory slot.
dds.SetMaxThreads(i32(N))
// thread i:
fut: dds.Future_Tricks
dds.SolveBoard(dl, dds.TARGET_FIND_MAX, .All, .Auto_Skip_Single, &fut, i32(i)) // threadIndex = i
```

For most workloads the batched functions (model 1) are simpler *and* faster — reach for model 2 only when
you already have a thread pool and want DDS to slot into it.

### The pool is process-global — one consequence

`SetMaxThreads` / `SetResources` configure, and `FreeMemory` tears down, a **single process-wide** DDS
state. That means DDS calls from different threads share it, and **`FreeMemory` frees *everyone's* TT
memory**. Practical fallout: the test suite runs serially (`-define:ODIN_TEST_THREADS=1` in the `just test`
recipe) so that one test's `defer dds.FreeMemory()` can't tear the pool down under another test running
concurrently. See [Memory lifecycle](#memory-lifecycle).

### Legacy vs modern threading

For context (not applicable to these bindings): DDS v3.0.0 adds a modern C++ API that **inverts** this
model — instead of a global pool you configure, "each thread creates its own context" (`SolverContext`),
owns it with no contention, and you always manage threads yourself. **These bindings wrap the legacy C ABI**,
where DDS owns the pool as described above. If you later bind the v3 C++ API, the threading section changes
wholesale.

---

## Memory lifecycle

`dds.FreeMemory()` returns the per-thread TT pool to the OS. It's safe to call — later DDS calls
re-allocate as needed. In a short-lived program it's optional (process exit frees everything), but a
long-running host should call it between workloads.

The responsible pattern is `defer` right after init, so the pool is released on **every** exit path
(including early error returns) without a teardown call at each one:

```odin
dds.SetMaxThreads(0)
defer dds.FreeMemory()
// ... work ...
```

Every example and test in this repo follows this pattern. (Because the pool is global, don't run
`FreeMemory`-using calls concurrently — see [above](#the-pool-is-process-global--one-consequence).)

---

## Return codes

Every solver function returns `dds.Return_Code`; `.NO_FAULT` (`1`) is success, everything else is an error.
Turn a code into text with `dds.error_message(code)` — a convenience wrapper that returns an Odin `string`
(the raw C `dds.ErrorMessage(code, &buf)` fills an `[80]i8` buffer instead):

```odin
if rc := dds.CalcDDtable(td, &res); rc != .NO_FAULT {
    fmt.eprintln("CalcDDtable failed:", dds.error_message(rc))
}
```

Common codes (full list in `dds.odin` and the DDS source doc):

| `Return_Code`      | Value | Meaning |
| ------------------ | ----- | ------- |
| `.NO_FAULT`        | 1     | Success |
| `.UNKNOWN_FAULT`   | -1    | Fopen failed, or `AnalyseAllPlays*` board-count mismatch |
| `.ZERO_CARDS`      | -2    | No cards supplied |
| `.TARGET_TOO_HIGH` | -3    | `target` exceeds the tricks available |
| `.DUPLICATE_CARDS` | -4    | A card appears in more than one hand |
| `.SUIT_OR_RANK`    | -12   | Bad suit or rank in a play trace |
| `.THREAD_MISSING`  | -104  | `SetThreading` backend not compiled in |
| `.CHUNK_SIZE`      | -301  | Bad `chunkSize` to a chunked solver |

---

## Introspection

`dds.GetDDSInfo(&info)` fills a `dds.DDS_Info` with the library's own configuration — version
(`major/minor/patch`), `numCores`, the active `threading` backend (`Threading`), `noOfThreads` actually
configured, and the compiler/constructor it was built with. Handy to confirm init took effect and which
threading system is live. Shown in [`examples/smoke.odin`](../examples/smoke.odin) and
[`examples/threading.odin`](../examples/threading.odin).

---

## See also

- [`external/dds/doc/dll-description.md`](../external/dds/doc/dll-description.md) — full DDS interface reference (all structs/fields/functions).
- [`examples/`](../examples) — a runnable, tested program per entry point.
- [`README.md`](../README.md) — build, bindgen regeneration, and repo layout.
