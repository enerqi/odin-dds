// Port of external/dds/examples/AnalysePlayPBN.cpp.
//
// AnalysePlayPBN is AnalysePlayBin (running trick-by-trick double-dummy analysis of a played line; see
// that file) with the deal and the play given as PBN-style strings instead of binary arrays. The play
// string is the played cards concatenated, two characters each (suit letter + rank). Use this form when
// your deals/plays already come as text. Output is the same dds.Solved_Play trick trace.
//
// Run:  just run analyse_play_pbn
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

		play := hands.play_trace_pbn(hands.PLAY_PBN[handno])
		solved: dds.Solved_Play
		if rc := dds.AnalysePlayPBN(dl, play, &solved); rc != .NO_FAULT {
			fmt.eprintln("AnalysePlayPBN failed:", dds.error_message(rc))
			continue
		}

		hands.print_pbn_hand(fmt.tprintf("AnalysePlayPBN, hand %d", handno + 1), hands.PBN[handno])
		hands.print_solved_play(&solved)
		fmt.println()
	}
}
