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

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads() // required one-time init (default 0 = auto thread count)

	for handno in 0 ..< len(hands.DEALS) {
		table_deal: dds.Table_Deal
		table_deal.cards = hands.DEALS[handno] // [Hand][Suit] matches ddTableDeal.cards

		res: dds.Table_Results
		if rc := dds.CalcDDtable(table_deal, &res); rc != .NO_FAULT {
			fmt.eprintln("CalcDDtable failed:", dds.error_message(rc))
			continue
		}

		hands.print_hand(fmt.tprintf("CalcDDtable, hand %d", handno + 1), table_deal.cards)
		hands.print_table(&res)
		fmt.println()
	}
}
