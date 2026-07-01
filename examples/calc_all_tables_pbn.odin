// Port of external/dds/examples/CalcAllTablesPBN.cpp.
//
// CalcAllTablesPBN is CalcAllTables (many double-dummy tables in one parallel call) with the deals
// supplied as PBN strings. Same trumpFilter / mode / Tables_Res behaviour as calc_all_tables; see that
// file. Handy for bulk-evaluating a set of PBN deals.
//
// Run:  just run calc_all_tables_pbn
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()

	deals: dds.Table_Deals_Pbn
	deals.noOfTables = i32(len(hands.PBN))
	for handno in 0 ..< len(hands.PBN) {
		hands.set_chars(deals.deals[handno].cards[:], hands.PBN[handno])
	}

	filter: [dds.Strain]b32
	res: dds.Tables_Res
	par: dds.All_Par_Results
	if rc := dds.CalcAllTablesPBN(&deals, 0, &filter, &res, &par); rc != .NO_FAULT {
		fmt.eprintln("CalcAllTablesPBN failed:", dds.error_message(rc))
		return
	}

	for handno in 0 ..< len(hands.PBN) {
		hands.print_pbn_hand(fmt.tprintf("CalcAllTablesPBN, hand %d", handno + 1), hands.PBN[handno])
		hands.print_table(&res.results[handno])
		fmt.println()
	}
}
