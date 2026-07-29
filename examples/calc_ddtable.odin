// Port of external/dds/examples/CalcDDtable.cpp.
//
// CalcDDtable computes the full "double-dummy table" for a deal: how many tricks each of the four
// players would take as declarer in each of the five strains (the 4 trump suits + no-trump) -- all
// 5 x 4 = 20 combinations at once. Where SolveBoard answers "best play from HERE", CalcDDtable answers
// the higher-level question "what is this deal worth in every possible contract?", which is the basis
// for hand valuation, par calculation, and deal statistics. It is much faster than 20 SolveBoard calls
// because it shares work across strains.
//
// Input (dds.Table_Deal): just the 52 cards -- cards[hand][suit] as Holdings. No trump/lead needed,
// since it evaluates every strain and declarer.
// Output (dds.Table_Results): resTable[strain][declarer] = tricks that declarer takes in that strain.
//
// Run:  just run calc_ddtable
package main

import "core:fmt"
import "core:testing"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads() // required one-time init (default 0 = auto thread count)
	defer dds.FreeMemory()

	for cards, handno in hands.DEALS {
		table_deal: dds.Table_Deal
		table_deal.cards = cards // [Hand][Suit] matches ddTableDeal.cards

		table_results: dds.Table_Results
		if rc := dds.CalcDDtable(table_deal, &table_results); rc != .NO_FAULT {
			fmt.eprintln("CalcDDtable failed:", dds.error_message(rc))
			continue
		}

		hands.print_hand(fmt.tprintf("CalcDDtable, hand %d", handno + 1), table_deal.cards)
		hands.print_table(&table_results)
		fmt.println()
	}
}

// Same computation as `main` without the printing: solve DEALS[0] and assert its full double-dummy
// table (strain x declarer), verified against the known result for that board. `just test1 calc_ddtable`
// runs it via `odin test`, which invokes @(test) procs and ignores `main`.
@(test)
test_calc_ddtable :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	table_deal: dds.Table_Deal
	table_deal.cards = hands.DEALS[0]

	table_results: dds.Table_Results
	testing.expect_value(t, dds.CalcDDtable(table_deal, &table_results), dds.Return_Code.NO_FAULT)
	hands.expect_table(t, &table_results, hands.DDTABLE_0)
}
