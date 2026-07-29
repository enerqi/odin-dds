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

	for pbn, handno in hands.PBN {
		table_deal_pbn: dds.Table_Deal_Pbn
		hands.set_chars(table_deal_pbn.cards[:], pbn)

		table_results: dds.Table_Results
		if rc := dds.CalcDDtablePBN(table_deal_pbn, &table_results); rc != .NO_FAULT {
			fmt.eprintln("CalcDDtablePBN failed:", dds.error_message(rc))
			continue
		}

		hands.print_pbn_hand(fmt.tprintf("CalcDDtablePBN, hand %d", handno + 1), pbn)
		hands.print_table(&table_results)
		fmt.println()
	}
}

// Solve PBN board 0 and assert its full double-dummy table -- must match the binary calc_ddtable result
// for the same board. `just test1 calc_ddtable_pbn` runs this via `odin test`.
@(test)
test_calc_ddtable_pbn :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	table_deal_pbn: dds.Table_Deal_Pbn
	hands.set_chars(table_deal_pbn.cards[:], hands.PBN[0])

	table_results: dds.Table_Results
	testing.expect_value(t, dds.CalcDDtablePBN(table_deal_pbn, &table_results), dds.Return_Code.NO_FAULT)
	hands.expect_table(t, &table_results, hands.DDTABLE_0)
}
