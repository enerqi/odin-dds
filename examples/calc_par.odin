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

	for cards, handno in hands.DEALS {
		// Binary deal -> CalcPar gives table + par together.
		table_deal: dds.Table_Deal
		table_deal.cards = cards
		table_results: dds.Table_Results
		par_results: dds.Par_Results
		if rc := dds.CalcPar(table_deal, hands.VUL[handno], &table_results, &par_results); rc != .NO_FAULT {
			fmt.eprintln("CalcPar failed:", dds.error_message(rc))
			continue
		}

		// The same deal as PBN via CalcParPBN -- should yield an identical par.
		table_deal_pbn: dds.Table_Deal_Pbn
		hands.set_chars(table_deal_pbn.cards[:], hands.PBN[handno])
		table_results_pbn: dds.Table_Results
		par_results_pbn: dds.Par_Results
		if rc := dds.CalcParPBN(table_deal_pbn, &table_results_pbn, hands.VUL[handno], &par_results_pbn);
		   rc != .NO_FAULT {
			fmt.eprintln("CalcParPBN failed:", dds.error_message(rc))
			continue
		}

		fmt.printfln("CalcPar, hand %d (vul %v)", handno + 1, hands.VUL[handno])
		hands.print_table(&table_results)
		fmt.println("  via CalcPar (binary deal):")
		hands.print_par(&par_results)
		fmt.println("  via CalcParPBN (PBN deal):")
		hands.print_par(&par_results_pbn)
		fmt.println()
	}
}
