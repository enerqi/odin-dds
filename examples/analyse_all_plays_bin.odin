// Port of external/dds/examples/AnalyseAllPlaysBin.cpp.
//
// AnalyseAllPlaysBin is the batched form of AnalysePlayBin: it runs trick-by-trick double-dummy
// analysis over MANY (deal, played-line) pairs in one parallel call. Use it to analyse a whole session
// of boards at once -- e.g. producing the per-card "gained/lost" trace for every deal in a tournament.
//
// Inputs: dds.Boards (the deals) alongside dds.Play_Traces_Bin (a play trace per deal); the two must
// agree on noOfBoards. Output (dds.Solved_Plays): solved[i] is the Solved_Play trick trace for deal i.
//
// Run:  just run analyse_all_plays_bin
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()

	bo: dds.Boards
	plays: dds.Play_Traces_Bin
	bo.noOfBoards = i32(len(hands.DEALS))
	plays.noOfBoards = i32(len(hands.DEALS))

	for handno in 0 ..< len(hands.DEALS) {
		bo.deals[handno].trump = hands.TRUMP[handno]
		bo.deals[handno].first = hands.FIRST[handno]
		bo.deals[handno].remainCards = hands.DEALS[handno]
		plays.plays[handno] = hands.play_trace_bin(hands.PLAY_PBN[handno])
	}

	solved: dds.Solved_Plays
	if rc := dds.AnalyseAllPlaysBin(&bo, &plays, &solved); rc != .NO_FAULT {
		fmt.eprintln("AnalyseAllPlaysBin failed:", dds.error_message(rc))
		return
	}

	for handno in 0 ..< len(hands.DEALS) {
		hands.print_hand(fmt.tprintf("AnalyseAllPlaysBin, hand %d", handno + 1), hands.DEALS[handno])
		hands.print_solved_play(&solved.solved[handno])
		fmt.println()
	}
}
