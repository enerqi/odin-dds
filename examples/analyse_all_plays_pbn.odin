// Port of external/dds/examples/AnalyseAllPlaysPBN.cpp.
//
// AnalyseAllPlaysPBN is AnalyseAllPlaysBin (batched trick-by-trick double-dummy analysis of many played
// lines; see that file) with deals and plays supplied as PBN strings. Output is the same
// dds.Solved_Plays batch of trick traces. Use it to bulk-analyse a set of text-format deals + plays.
//
// Run:  just run analyse_all_plays_pbn
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()

	bo: dds.Boards_Pbn
	plays: dds.Play_Traces_Pbn
	bo.noOfBoards = i32(len(hands.PBN))
	plays.noOfBoards = i32(len(hands.PBN))

	for handno in 0 ..< len(hands.PBN) {
		bo.deals[handno].trump = hands.TRUMP[handno]
		bo.deals[handno].first = hands.FIRST[handno]
		hands.set_chars(bo.deals[handno].remainCards[:], hands.PBN[handno])
		plays.plays[handno] = hands.play_trace_pbn(hands.PLAY_PBN[handno])
	}

	solved: dds.Solved_Plays
	if rc := dds.AnalyseAllPlaysPBN(&bo, &plays, &solved); rc != .NO_FAULT {
		fmt.eprintln("AnalyseAllPlaysPBN failed:", dds.error_message(rc))
		return
	}

	for handno in 0 ..< len(hands.PBN) {
		hands.print_pbn_hand(fmt.tprintf("AnalyseAllPlaysPBN, hand %d", handno + 1), hands.PBN[handno])
		hands.print_solved_play(&solved.solved[handno])
		fmt.println()
	}
}
