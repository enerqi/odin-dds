package main

import "core:fmt"
import "core:os"

import dds ".."

// Smoke test / getting-started example. Links against the DDS static lib, reports the library's own
// build info via GetDDSInfo (version, core count, which threading system is active), then solves one
// full deal table with CalcDDtable -- a minimal end-to-end check that the bindings link and run, while
// exercising the Odin wrapper types (Holding bit_set, Strain/Hand/Suit enums, enumerated arrays).
// `just run` builds and runs this. See the other examples for each specific DDS entry point.
main :: proc() {
	// DDS requires one-time init before any other call: it sizes thread-local transposition-table
	// memory and computes constant tables. The DLL does this automatically from DllMain, but a
	// STATIC lib on Windows has no auto-init (DllMain never fires when statically linked), so we
	// must call it ourselves. 0 = let DDS pick the thread count from the core count.
	dds.SetMaxThreads(0)

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
	deal: dds.Table_Deal
	deal.cards[.North][.Spades] = full_suit
	deal.cards[.East][.Hearts] = full_suit
	deal.cards[.South][.Diamonds] = full_suit
	deal.cards[.West][.Clubs] = full_suit

	res: dds.Table_Results
	if rc := dds.CalcDDtable(deal, &res); rc != .NO_FAULT {
		fmt.eprintln("CalcDDtable failed:", dds.error_message(rc))
		os.exit(1)
	}

	// resTable is [Strain][Hand]i32 -- read a few entries through the enums.
	fmt.printfln("Tricks in NT by North:      %d", res.resTable[.NT][.North])
	fmt.printfln("Tricks in Spades by North:  %d", res.resTable[.Spades][.North])
	fmt.printfln("Tricks in Hearts by East:   %d", res.resTable[.Hearts][.East])
}
