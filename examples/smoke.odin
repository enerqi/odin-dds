package main

import "core:fmt"
import "core:os"
import "core:testing"

import dds ".."

// Smoke test / getting-started example. Links against the DDS static lib, reports the library's own
// build info via GetDDSInfo (version, core count, which threading system is active), then solves one
// full deal table with CalcDDtable -- a minimal end-to-end check that the bindings link and run, while
// exercising the Odin wrapper types (Holding bit_set, Strain/Hand/Suit enums, enumerated arrays).
// `just run` builds and runs this. See the other examples for each specific DDS entry point.
main :: proc() {
	// DDS requires one-time init before any other call: it sizes thread-local transposition-table
	// memory and computes constant tables. The DLL does this automatically from DllMain, but the
	// STATIC lib these bindings link has no auto-init on any platform (DllMain never fires when
	// statically linked, and the Unix constructor path is not compiled in), so we must call it
	// ourselves. 0 = let DDS pick the thread count from the core count.
	dds.SetMaxThreads(0)
	defer dds.FreeMemory()

	info: dds.DDS_Info
	dds.GetDDSInfo(&info)
	fmt.printfln(
		"DDS %d.%d.%d  cores=%d  threads=%d  threading=%d",
		info.major,
		info.minor,
		info.patch,
		info.numCores,
		info.noOfThreads,
		info.threading,
	)

	// A valid 52-card deal: each hand holds one complete suit. `Holding` is a bit_set over ranks, and
	// `Table_Deal.cards` is an enumerated array indexed [Hand][Suit].
	full_suit := dds.Holding{._2, ._3, ._4, ._5, ._6, ._7, ._8, ._9, .Ten, .Jack, .Queen, .King, .Ace}
	table_deal: dds.Table_Deal
	table_deal.cards[.North][.Spades] = full_suit
	table_deal.cards[.East][.Hearts] = full_suit
	table_deal.cards[.South][.Diamonds] = full_suit
	table_deal.cards[.West][.Clubs] = full_suit

	table_results: dds.Table_Results
	if rc := dds.CalcDDtable(table_deal, &table_results); rc != .NO_FAULT {
		fmt.eprintln("CalcDDtable failed:", dds.error_message(rc))
		os.exit(1)
	}

	// resTable is [Strain][Hand]i32 -- read a few entries through the enums.
	fmt.printfln("Tricks in NT by North:      %d", table_results.resTable[.NT][.North])
	fmt.printfln("Tricks in Spades by North:  %d", table_results.resTable[.Spades][.North])
	fmt.printfln("Tricks in Hearts by East:   %d", table_results.resTable[.Hearts][.East])
}

// `odin test` picks up @(test) procs and ignores `main`, so the example doubles as a test. Same deal as
// `main`, minus the info/printing: assert the known trick counts instead. `just test1 smoke` runs it.
@(test)
test_smoke :: proc(t: ^testing.T) {
	dds.SetMaxThreads(0)
	defer dds.FreeMemory()

	full_suit := dds.Holding{._2, ._3, ._4, ._5, ._6, ._7, ._8, ._9, .Ten, .Jack, .Queen, .King, .Ace}
	table_deal: dds.Table_Deal
	table_deal.cards[.North][.Spades] = full_suit
	table_deal.cards[.East][.Hearts] = full_suit
	table_deal.cards[.South][.Diamonds] = full_suit
	table_deal.cards[.West][.Clubs] = full_suit

	table_results: dds.Table_Results
	testing.expect_value(t, dds.CalcDDtable(table_deal, &table_results), dds.Return_Code.NO_FAULT)
	testing.expect_value(t, table_results.resTable[.NT][.North], 0)
	testing.expect_value(t, table_results.resTable[.Spades][.North], 13)
	testing.expect_value(t, table_results.resTable[.Hearts][.East], 13)
}
