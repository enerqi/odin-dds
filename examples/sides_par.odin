// Example for SidesPar / SidesParBin / ConvertToSidesTextFormat (DDS ships no example for these).
//
// The "sides" par calls compute par SEPARATELY for each side (NS and EW) in one call. Normally both
// sides agree, but in rare deals par depends on which side gets to bid its best contract first, so
// returning both is the fully-correct answer. Two flavours:
//   - SidesPar     -> [2]Par_Results_Dealer: par as ready-made TEXT contract strings, one set per side.
//   - SidesParBin  -> [2]Par_Results_Master: par as STRUCTURED contracts (level/denom/seats fields),
//     better for programmatic use. ConvertToSidesTextFormat turns that structured result into a compact
//     two-line Par_Text_Results for display.
//
// Input: a DD table (computed here with CalcDDtable) + a Vulnerability.
//
// Run:  just run sides_par
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

		fmt.printfln("SidesPar, hand %d (vul %v)", handno + 1, hands.VUL[handno])

		// Text form: one Par_Results_Dealer per side.
		sides: [2]dds.Par_Results_Dealer
		if rc := dds.SidesPar(&table, &sides, hands.VUL[handno]); rc != .NO_FAULT {
			fmt.eprintln("SidesPar failed:", dds.error_message(rc))
			continue
		}
		for side in dds.Side {
			fmt.printfln("  %v side:", side)
			hands.print_dealer_par(&sides[int(side)])
		}

		// Structured form + text conversion.
		sides_bin: [2]dds.Par_Results_Master
		if rc := dds.SidesParBin(&table, &sides_bin, hands.VUL[handno]); rc != .NO_FAULT {
			fmt.eprintln("SidesParBin failed:", dds.error_message(rc))
			continue
		}
		text: dds.Par_Text_Results
		if rc := dds.ConvertToSidesTextFormat(&sides_bin[0], &text); rc != .NO_FAULT {
			fmt.eprintln("ConvertToSidesTextFormat failed:", dds.error_message(rc))
			continue
		}
		fmt.println("  ConvertToSidesTextFormat:")
		hands.print_par_text(&text)
		fmt.println()
	}
}
