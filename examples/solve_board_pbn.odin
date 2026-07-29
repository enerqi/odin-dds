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
		deal_pbn: dds.Deal_Pbn
		deal_pbn.trump = hands.TRUMP[handno]
		deal_pbn.first = hands.FIRST[handno]
		hands.set_chars(deal_pbn.remainCards[:], hands.PBN[handno])

		future_all: dds.Future_Tricks
		if rc := dds.SolveBoardPBN(deal_pbn, dds.TARGET_FIND_MAX, .All, .Auto_Skip_Single, &future_all);
		   rc != .NO_FAULT {
			fmt.eprintln("SolveBoardPBN failed:", dds.error_message(rc))
			continue
		}

		future_optimal: dds.Future_Tricks
		if rc := dds.SolveBoardPBN(deal_pbn, dds.TARGET_FIND_MAX, .All_Optimal, .Auto_Skip_Single, &future_optimal);
		   rc != .NO_FAULT {
			fmt.eprintln("SolveBoardPBN failed:", dds.error_message(rc))
			continue
		}

		hands.print_pbn_hand(fmt.tprintf("SolveBoardPBN, hand %d", handno + 1), hands.PBN[handno])
		hands.print_future_tricks("solutions = All (every card + score)", &future_all)
		hands.print_future_tricks("solutions = All_Optimal (best cards only)", &future_optimal)
		fmt.println()
	}
}

// PBN board 0, same solve as solve_board: best card yields 5 tricks for the hand on lead.
@(test)
test_solve_board_pbn :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	deal_pbn: dds.Deal_Pbn
	deal_pbn.trump = hands.TRUMP[0]
	deal_pbn.first = hands.FIRST[0]
	hands.set_chars(deal_pbn.remainCards[:], hands.PBN[0])

	future_tricks: dds.Future_Tricks
	testing.expect_value(
		t,
		dds.SolveBoardPBN(deal_pbn, dds.TARGET_FIND_MAX, .All, .Auto_Skip_Single, &future_tricks),
		dds.Return_Code.NO_FAULT,
	)
	testing.expect(t, future_tricks.cards > 0)
	testing.expect_value(t, future_tricks.score[0], 5)
}
