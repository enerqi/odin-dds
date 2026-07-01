// Port of external/dds/examples/AnalysePlayBin.cpp.
//
// AnalysePlayBin replays an actual sequence of played cards through the double-dummy solver and reports
// the DD trick total for the declaring side after each card. Because the total only changes when
// someone plays a card that isn't double-dummy optimal, this pinpoints exactly WHERE and by HOW MUCH a
// line of play gained or lost tricks -- the engine behind "hand analysis" / error-spotting tools.
//
// Inputs:
//   - the deal (dds.Deal) the play started from.
//   - a play trace (dds.Play_Trace_Bin): number of cards, then parallel suit[] / rank[] arrays giving
//     the cards in the order they were played. Here we derive it from a compact card string.
// Output (dds.Solved_Play): tricks[i] = the DD trick count for the declaring side after the i-th card;
// a drop from one entry to the next marks a card that cost a trick.
//
// Run:  just run analyse_play_bin
package main

import "core:fmt"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	for handno in 0 ..< len(hands.DEALS) {
		dl: dds.Deal
		dl.trump = hands.TRUMP[handno]
		dl.first = hands.FIRST[handno]
		dl.remainCards = hands.DEALS[handno]

		play := hands.play_trace_bin(hands.PLAY_PBN[handno])
		solved: dds.Solved_Play
		if rc := dds.AnalysePlayBin(dl, play, &solved); rc != .NO_FAULT {
			fmt.eprintln("AnalysePlayBin failed:", dds.error_message(rc))
			continue
		}

		hands.print_hand(fmt.tprintf("AnalysePlayBin, hand %d", handno + 1), dl.remainCards)
		hands.print_solved_play(&solved)
		fmt.println()
	}
}
