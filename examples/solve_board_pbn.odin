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
import "core:testing"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

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

// PBN board 0, same solve as solve_board: best card yields 5 tricks for the hand on lead.
@(test)
test_solve_board_pbn :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	dl: dds.Deal_Pbn
	dl.trump = hands.TRUMP[0]
	dl.first = hands.FIRST[0]
	hands.set_chars(dl.remainCards[:], hands.PBN[0])

	fut: dds.Future_Tricks
	testing.expect_value(t, dds.SolveBoardPBN(dl, dds.TARGET_FIND_MAX, .All, .Auto_Skip_Single, &fut), dds.Return_Code.NO_FAULT)
	testing.expect(t, fut.cards > 0)
	testing.expect_value(t, fut.score[0], 5)
}
