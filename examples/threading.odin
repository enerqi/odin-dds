// Threading / resource lifecycle -- SetResources, SetThreading, GetDDSInfo, FreeMemory.
//
// DDS keeps a "transposition table" memory pool per worker thread (it can be hundreds of MB). This
// example shows the configuration and teardown entry points that the other examples gloss over:
//
//   - SetResources(maxMemoryMB, maxThreads): the fuller alternative to SetMaxThreads for the required
//     one-time init. 0/0 = let DDS pick memory and thread count from the machine. Pass limits to cap
//     memory or force a thread count.
//   - SetThreading(system): choose which multi-threading backend DDS uses (Threading enum). Returns a
//     Return_Code -- .THREAD_MISSING if that backend wasn't compiled into the library. Our static lib
//     is built with WinAPI/STL/STLIMPL/PPLIMPL (no OpenMP -- see src/build.cmd).
//   - GetDDSInfo: read back the resulting configuration.
//   - FreeMemory(): return the per-thread pool to the OS. Not needed in short programs (process exit
//     frees it), but a long-running host should call it between workloads to release the memory.
//
// Run:  just run threading
package main

import "core:fmt"
import "core:testing"

import dds ".."
import "hands"

main :: proc() {
	// One-time init via SetResources instead of SetMaxThreads. maxThreads defaults to 0 (= auto).
	dds.SetResources(0)
	// Return the per-thread transposition-table pool at scope exit. `defer` right after init is the
	// responsible pattern: the memory is released on every exit path -- including the early `return`
	// below -- without a teardown call at each one. Not strictly needed here (process exit frees it),
	// but a long-running host should do this between workloads.
	defer dds.FreeMemory()

	// Select the WinAPI threading backend explicitly. If a backend isn't present, DDS returns
	// .THREAD_MISSING and keeps its current one.
	if rc := dds.SetThreading(.WinAPI); rc != .NO_FAULT {
		fmt.eprintln("SetThreading(.WinAPI):", dds.error_message(rc), "-- keeping the default backend")
	}

	info: dds.DDS_Info
	dds.GetDDSInfo(&info)
	fmt.printfln(
		"DDS %d.%d.%d  cores=%d  threads configured=%d  threading=%v  system=%v",
		info.major,
		info.minor,
		info.patch,
		info.numCores,
		info.noOfThreads,
		info.threading,
		info.system,
	)

	// Do some real work so the thread memory actually gets allocated.
	td: dds.Table_Deal
	td.cards = hands.DEALS[0]
	res: dds.Table_Results
	if rc := dds.CalcDDtable(td, &res); rc != .NO_FAULT {
		fmt.eprintln("CalcDDtable failed:", dds.error_message(rc))
		return
	}
	fmt.printfln("Solved a table (NT by North = %d tricks).", res.resTable[.NT][.North])
	// `defer dds.FreeMemory()` above releases the per-thread pool as this proc returns.
}

// Exercise the resource lifecycle -- SetResources init, real work, FreeMemory teardown -- and assert
// the board-0 table came out right. SetThreading is best-effort (.THREAD_MISSING if the backend isn't
// compiled in), so it is not asserted.
@(test)
test_threading :: proc(t: ^testing.T) {
	dds.SetResources(0)
	defer dds.FreeMemory()
	dds.SetThreading(.WinAPI) // best-effort; keep whatever backend is available

	td: dds.Table_Deal
	td.cards = hands.DEALS[0]
	res: dds.Table_Results
	testing.expect_value(t, dds.CalcDDtable(td, &res), dds.Return_Code.NO_FAULT)
	hands.expect_table(t, &res, hands.DDTABLE_0)
}
