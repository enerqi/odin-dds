// Port of external/dds/examples/DealerPar.cpp.
//
// DealerPar is Par with the dealer taken into account. Plain Par assumes either side may open the
// bidding; in rare deals the result differs depending on WHO bids first (e.g. both sides can make 1NT),
// so DealerPar resolves par for a specific dealer. Use it when you need the strictly correct par for an
// actual auction rather than the side-independent value.
//
// Inputs: the DD table (dds.Table_Results, computed here with CalcDDtable), the dealer (Hand), and the
// Vulnerability. Output (dds.Par_Results_Dealer): the par score and the list of par contracts for that
// dealer.
//
// Run:  just run dealer_par
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	for cards, handno in hands.DEALS {
		table_deal: dds.Table_Deal
		table_deal.cards = cards
		table_results: dds.Table_Results
		if rc := dds.CalcDDtable(table_deal, &table_results); rc != .NO_FAULT {
			fmt.eprintln("CalcDDtable failed:", dds.error_message(rc))
			continue
		}

		par_results_dealer: dds.Par_Results_Dealer
		if rc := dds.DealerPar(&table_results, &par_results_dealer, hands.DEALER[handno], hands.VUL[handno]);
		   rc != .NO_FAULT {
			fmt.eprintln("DealerPar failed:", dds.error_message(rc))
			continue
		}

		fmt.printfln("DealerPar, hand %d (dealer %v, vul %v)", handno + 1, hands.DEALER[handno], hands.VUL[handno])
		hands.print_table(&table_results)
		hands.print_dealer_par(&par_results_dealer)
		fmt.println()
	}
}
