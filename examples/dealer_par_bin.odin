// Example for DealerParBin / ConvertToDealerTextFormat (DDS ships no example for these).
//
// DealerParBin is the STRUCTURED counterpart of DealerPar: same dealer-aware par calculation, but the
// contracts come back as Par_Results_Master (Contract_Type structs with level/denom/seats fields)
// instead of pre-formatted text -- so your program can inspect them. ConvertToDealerTextFormat renders
// that structured result into a single human-readable line, written into a caller-provided char buffer.
//
// Input: a DD table (CalcDDtable here), the dealer (Hand), and a Vulnerability.
//
// Run:  just run dealer_par_bin
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

		par_results_master: dds.Par_Results_Master
		if rc := dds.DealerParBin(&table_results, &par_results_master, hands.DEALER[handno], hands.VUL[handno]);
		   rc != .NO_FAULT {
			fmt.eprintln("DealerParBin failed:", dds.error_message(rc))
			continue
		}

		fmt.printfln("DealerParBin, hand %d (dealer %v, vul %v)", handno + 1, hands.DEALER[handno], hands.VUL[handno])
		hands.print_par_master(&par_results_master)

		// ConvertToDealerTextFormat writes a null-terminated line into a caller-supplied char buffer.
		buf: [256]u8
		if rc := dds.ConvertToDealerTextFormat(&par_results_master, cstring(rawptr(&buf[0]))); rc != .NO_FAULT {
			fmt.eprintln("ConvertToDealerTextFormat failed:", dds.error_message(rc))
			continue
		}
		fmt.printfln("  text: %s", string(cstring(rawptr(&buf[0]))))
		fmt.println()
	}
}
