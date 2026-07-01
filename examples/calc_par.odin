// Port-style example for CalcPar / CalcParPBN (DDS ships no example for these).
//
// CalcPar is a convenience call that fuses CalcDDtable + Par: from a raw deal it computes the full
// double-dummy table AND the par result in one step, returning both. Use it when you want par for a
// deal you have as cards and don't separately need to build the table yourself (compare par.odin, which
// calls CalcDDtable then Par). CalcParPBN is the same for a PBN deal.
//
// Inputs: a deal (Table_Deal or Table_Deal_Pbn) + a Vulnerability. Outputs: the Table_Results (filled
// in) and the Par_Results (score + contract text per Side).
//
// Run:  just run calc_par
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	for handno in 0 ..< len(hands.DEALS) {
		// Binary deal -> CalcPar gives table + par together.
		td: dds.Table_Deal
		td.cards = hands.DEALS[handno]
		table: dds.Table_Results
		pres: dds.Par_Results
		if rc := dds.CalcPar(td, hands.VUL[handno], &table, &pres); rc != .NO_FAULT {
			fmt.eprintln("CalcPar failed:", dds.error_message(rc))
			continue
		}

		// The same deal as PBN via CalcParPBN -- should yield an identical par.
		tdp: dds.Table_Deal_Pbn
		hands.set_chars(tdp.cards[:], hands.PBN[handno])
		table_pbn: dds.Table_Results
		pres_pbn: dds.Par_Results
		if rc := dds.CalcParPBN(tdp, &table_pbn, hands.VUL[handno], &pres_pbn); rc != .NO_FAULT {
			fmt.eprintln("CalcParPBN failed:", dds.error_message(rc))
			continue
		}

		fmt.printfln("CalcPar, hand %d (vul %v)", handno + 1, hands.VUL[handno])
		hands.print_table(&table)
		fmt.println("  via CalcPar (binary deal):")
		hands.print_par(&pres)
		fmt.println("  via CalcParPBN (PBN deal):")
		hands.print_par(&pres_pbn)
		fmt.println()
	}
}
