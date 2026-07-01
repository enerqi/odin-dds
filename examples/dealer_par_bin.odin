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
		td: dds.Table_Deal
		td.cards = hands.DEALS[handno]
		table: dds.Table_Results
		if rc := dds.CalcDDtable(td, &table); rc != .NO_FAULT {
			fmt.eprintln("CalcDDtable failed:", dds.error_message(rc))
			continue
		}

		pres: dds.Par_Results_Master
		if rc := dds.DealerParBin(&table, &pres, hands.DEALER[handno], hands.VUL[handno]); rc != .NO_FAULT {
			fmt.eprintln("DealerParBin failed:", dds.error_message(rc))
			continue
		}

		fmt.printfln("DealerParBin, hand %d (dealer %v, vul %v)", handno + 1, hands.DEALER[handno], hands.VUL[handno])
		hands.print_par_master(&pres)

		// ConvertToDealerTextFormat writes a null-terminated line into a caller-supplied char buffer.
		buf: [256]u8
		if rc := dds.ConvertToDealerTextFormat(&pres, cstring(rawptr(&buf[0]))); rc != .NO_FAULT {
			fmt.eprintln("ConvertToDealerTextFormat failed:", dds.error_message(rc))
			continue
		}
		fmt.printfln("  text: %s", string(cstring(rawptr(&buf[0]))))
		fmt.println()
	}
}
