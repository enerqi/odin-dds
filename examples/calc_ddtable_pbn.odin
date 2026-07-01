// Port of external/dds/examples/CalcDDtablePBN.cpp.
//
// CalcDDtablePBN is CalcDDtable (the full 5-strain x 4-declarer double-dummy table for a deal) with the
// deal given as a PBN string rather than Holding bit_sets. Reach for it when your deals are already in
// PBN text. The Table_Results output is identical to calc_ddtable; see that file.
//
// Run:  just run calc_ddtable_pbn
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()

	for handno in 0 ..< len(hands.PBN) {
		td: dds.Table_Deal_Pbn
		hands.set_chars(td.cards[:], hands.PBN[handno])

		res: dds.Table_Results
		if rc := dds.CalcDDtablePBN(td, &res); rc != .NO_FAULT {
			fmt.eprintln("CalcDDtablePBN failed:", dds.error_message(rc))
			continue
		}

		hands.print_pbn_hand(fmt.tprintf("CalcDDtablePBN, hand %d", handno + 1), hands.PBN[handno])
		hands.print_table(&res)
		fmt.println()
	}
}
