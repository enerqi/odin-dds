// Port of external/dds/examples/CalcAllTables.cpp.
//
// CalcAllTables is the batched form of CalcDDtable: it computes the full double-dummy table for MANY
// deals in a single call, spreading the work across threads. Use it when you have lots of deals to
// evaluate (e.g. simulations, a tournament's boards) -- it is substantially faster than calling
// CalcDDtable per deal.
//
// Extra parameters beyond a plain table:
//   - trumpFilter: a per-strain "exclude" flag ([Strain]b32). All-false (as here) computes every
//     strain; set an entry true to skip that strain and save time if you don't need it.
//   - mode + presp: mode carries a Vulnerability for an optional par calculation written into presp.
//     The C example passes mode = 0; presp must still be provided even when par isn't wanted.
// Output (dds.Tables_Res): results[i] is the Table_Results for the i-th input deal.
//
// Run:  just run calc_all_tables
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()

	deals: dds.Table_Deals
	deals.noOfTables = i32(len(hands.DEALS))
	for handno in 0 ..< len(hands.DEALS) {
		deals.deals[handno].cards = hands.DEALS[handno]
	}

	// trumpFilter is per-strain "exclude" flags; all false = compute every strain.
	filter: [dds.Strain]b32
	res: dds.Tables_Res
	par: dds.All_Par_Results // required output even when no par is requested (mode = 0, as in the C example)
	if rc := dds.CalcAllTables(&deals, 0, &filter, &res, &par); rc != .NO_FAULT {
		fmt.eprintln("CalcAllTables failed:", dds.error_message(rc))
		return
	}

	for handno in 0 ..< len(hands.DEALS) {
		hands.print_hand(fmt.tprintf("CalcAllTables, hand %d", handno + 1), hands.DEALS[handno])
		hands.print_table(&res.results[handno])
		fmt.println()
	}
}
