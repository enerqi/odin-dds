// Port of external/dds/examples/SolveBoardPBN.cpp.
//
// SolveBoardPBN is exactly SolveBoard (find the best card(s) for the hand on lead and the tricks they
// make, double-dummy) but the deal is supplied as a PBN deal string instead of Holding bit_sets. PBN
// is the standard text format for a bridge deal: a leading seat tag (e.g. "N:") then the four hands
// clockwise, each as "spades.hearts.diamonds.clubs". Use this form when your deals already come as PBN
// (from a file, a dealer program, etc.) and you would rather not unpack them into per-suit holdings.
//
// Everything else -- target / solutions / mode and the Future_Tricks result -- is identical to
// solve_board; see that file for the full explanation.
//
// Run:  just run solve_board_pbn
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()

	for handno in 0 ..< len(hands.PBN) {
		dl: dds.Deal_Pbn
		dl.trump = hands.TRUMP[handno]
		dl.first = hands.FIRST[handno]
		hands.set_chars(dl.remainCards[:], hands.PBN[handno])

		fut3: dds.Future_Tricks
		if rc := dds.SolveBoardPBN(dl, dds.TARGET_FIND_MAX, .All, .Auto_Skip_Single, &fut3); rc != .NO_FAULT {
			fmt.eprintln("SolveBoardPBN failed:", dds.error_message(rc))
			continue
		}

		fut2: dds.Future_Tricks
		if rc := dds.SolveBoardPBN(dl, dds.TARGET_FIND_MAX, .All_Optimal, .Auto_Skip_Single, &fut2); rc != .NO_FAULT {
			fmt.eprintln("SolveBoardPBN failed:", dds.error_message(rc))
			continue
		}

		hands.print_pbn_hand(fmt.tprintf("SolveBoardPBN, hand %d", handno + 1), hands.PBN[handno])
		hands.print_fut("solutions == 3", &fut3)
		hands.print_fut("solutions == 2", &fut2)
		fmt.println()
	}
}
