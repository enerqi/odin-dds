// Port of external/dds/examples/SolveBoard.cpp.
//
// SolveBoard is the core single-deal solver. Given a deal and whose turn it is to play, it works out,
// double-dummy (i.e. as if all four hands were visible and everyone plays perfectly), which card(s)
// the player-to-lead should play and how many tricks that side can then take. It answers "what is the
// best play here, and what does it achieve?" for one position.
//
// Inputs (dds.Deal):
//   - trump: the strain (a suit, or NT) that is trumps for this deal.
//   - first: the hand on lead to the current trick (Hand encoding).
//   - currentTrickSuit/Rank: any cards already played to the trick in progress (none here).
//   - remainCards[hand][suit]: each hand's remaining cards, as a Holding bit_set of ranks.
// Control knobs:
//   - target: minimum tricks to look for; TARGET_FIND_MAX (-1) = just find the maximum.
//   - solutions: how much to return -- .One (a best card), .All_Optimal (all cards reaching the
//     target), or .All (every card with its own score). Here we show .All then .All_Optimal.
//   - mode: transposition-table reuse; .Auto_Skip_Single is the normal choice.
// Output (dds.Future_Tricks): for each returned card -- its suit+rank, the lower equivalent cards it
// stands in for (equals), and score = the number of tricks makeable after playing it.
//
// Run:  just run solve_board
package main

import "core:fmt"
import "core:testing"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads() // required one-time init (default 0 = auto thread count)
	defer dds.FreeMemory()

	for handno in 0 ..< len(hands.DEALS) {
		dl: dds.Deal
		dl.trump = hands.TRUMP[handno]
		dl.first = hands.FIRST[handno]
		dl.remainCards = hands.DEALS[handno] // [Hand][Suit] already matches remainCards

		// solutions = .All: return EVERY playable card for the hand on lead, each annotated with the
		// tricks it yields -- shows how much a suboptimal card costs. target = TARGET_FIND_MAX (find
		// the best), threadIndex defaults to 0.
		fut3: dds.Future_Tricks
		if rc := dds.SolveBoard(dl, dds.TARGET_FIND_MAX, .All, .Auto_Skip_Single, &fut3); rc != .NO_FAULT {
			fmt.eprintln("SolveBoard failed:", dds.error_message(rc))
			continue
		}

		// solutions = .All_Optimal: return only the cards that reach the maximum -- the equally-best plays.
		fut2: dds.Future_Tricks
		if rc := dds.SolveBoard(dl, dds.TARGET_FIND_MAX, .All_Optimal, .Auto_Skip_Single, &fut2); rc != .NO_FAULT {
			fmt.eprintln("SolveBoard failed:", dds.error_message(rc))
			continue
		}

		hands.print_hand(fmt.tprintf("SolveBoard, hand %d", handno + 1), dl.remainCards)
		hands.print_fut("solutions = All (every card + score)", &fut3)
		hands.print_fut("solutions = All_Optimal (best cards only)", &fut2)
		fmt.println()
	}
}

// Solve board 0 for the max makeable tricks by the hand on lead. North on lead in spades can make 5;
// assert that top score. (Same value the other solve_* examples produce for this board.)
@(test)
test_solve_board :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	dl: dds.Deal
	dl.trump = hands.TRUMP[0]
	dl.first = hands.FIRST[0]
	dl.remainCards = hands.DEALS[0]

	fut: dds.Future_Tricks
	testing.expect_value(t, dds.SolveBoard(dl, dds.TARGET_FIND_MAX, .All, .Auto_Skip_Single, &fut), dds.Return_Code.NO_FAULT)
	testing.expect(t, fut.cards > 0)
	testing.expect_value(t, fut.score[0], 5) // best card yields 5 tricks
}
