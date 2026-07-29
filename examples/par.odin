// Port of external/dds/examples/Par.cpp.
//
// Par takes a completed double-dummy table and works out the "par" result: the contract(s) that would
// be reached if both sides bid perfectly -- each side bidding on until the opponents' best action is to
// double or pass, including profitable sacrifices. It is the objective yardstick for "what should this
// board score", widely used to compare bidding/results against optimal. Par depends on who is
// vulnerable (doubled penalties change the sacrifice maths), so it takes a Vulnerability.
//
// Inputs:
//   - a dds.Table_Results (the DD table). The C example fills it from canned data via SetTable; we
//     compute it with CalcDDtable instead, which is more illustrative.
//   - vulnerable: the Vulnerability for this deal.
// Output (dds.Par_Results): the par score and contract text for each Side (NS / EW).
//
// Run:  just run par
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	for handno in 0 ..< len(hands.DEALS) {
		table_deal: dds.Table_Deal
		table_deal.cards = hands.DEALS[handno]
		table_results: dds.Table_Results
		if rc := dds.CalcDDtable(table_deal, &table_results); rc != .NO_FAULT {
			fmt.eprintln("CalcDDtable failed:", dds.error_message(rc))
			continue
		}

		par_results: dds.Par_Results
		if rc := dds.Par(&table_results, &par_results, hands.VUL[handno]); rc != .NO_FAULT {
			fmt.eprintln("Par failed:", dds.error_message(rc))
			continue
		}

		fmt.printfln("Par, hand %d (vul %v)", handno + 1, hands.VUL[handno])
		hands.print_table(&table_results)
		hands.print_par(&par_results)
		fmt.println()
	}
}
