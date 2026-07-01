// Port of external/dds/examples/CalcDDtablePBN.cpp.
//
// CalcDDtablePBN is CalcDDtable (the full 5-strain x 4-declarer double-dummy table for a deal) with the
// deal given as a PBN string rather than Holding bit_sets. Reach for it when your deals are already in
// PBN text. The Table_Results output is identical to calc_ddtable; see that file.
//
// Run:  just run calc_ddtable_pbn
package main

import "core:fmt"
import "core:testing"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

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

// Solve PBN board 0 and assert its full double-dummy table -- must match the binary calc_ddtable result
// for the same board. `just test_examples` runs this via `odin test`.
@(test)
test_calc_ddtable_pbn :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	td: dds.Table_Deal_Pbn
	hands.set_chars(td.cards[:], hands.PBN[0])

	res: dds.Table_Results
	testing.expect_value(t, dds.CalcDDtablePBN(td, &res), dds.Return_Code.NO_FAULT)
	hands.expect_table(t, &res, hands.DDTABLE_0)
}
