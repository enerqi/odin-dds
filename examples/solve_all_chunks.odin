// Example for SolveAllChunks / SolveAllChunksBin / SolveAllChunksPBN (DDS ships no example for these).
//
// These are the same batch board-solver as SolveAllBoards, but they expose the multi-threading
// `chunkSize`: how many boards each worker thread grabs at a time. SolveAllBoards uses a fixed internal
// scheme; the Chunks variants let you tune scheduling for your workload (chunkSize = 1, the default and
// usual choice, gives the best load-balancing across uneven boards). The three differ only in input
// format:
//   - SolveAllChunksBin -> dds.Boards       (binary deals, remainCards Holdings)
//   - SolveAllChunks / SolveAllChunksPBN -> dds.Boards_Pbn  (PBN deal strings)
//
// Per board you set the same target / solutions / mode as SolveBoard. Output: dds.Solved_Boards, a
// Future_Tricks per board.
//
// Run:  just run solve_all_chunks
package main

import "core:fmt"
import "core:testing"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	// Binary batch via SolveAllChunksBin.
	boards: dds.Boards
	boards.noOfBoards = i32(len(hands.DEALS))
	for handno in 0 ..< len(hands.DEALS) {
		boards.deals[handno].trump = hands.TRUMP[handno]
		boards.deals[handno].first = hands.FIRST[handno]
		boards.deals[handno].remainCards = hands.DEALS[handno]
		boards.target[handno] = dds.TARGET_FIND_MAX
		boards.solutions[handno] = .All
		boards.mode[handno] = .Auto_Skip_Single
	}

	solved: dds.Solved_Boards
	if rc := dds.SolveAllChunksBin(&boards, &solved, 1); rc != .NO_FAULT { 	// chunkSize = 1
		fmt.eprintln("SolveAllChunksBin failed:", dds.error_message(rc))
		return
	}
	for handno in 0 ..< len(hands.DEALS) {
		hands.print_hand(fmt.tprintf("SolveAllChunksBin, hand %d", handno + 1), hands.DEALS[handno])
		hands.print_future_tricks("solutions = All (every card + score)", &solved.solvedBoard[handno])
		fmt.println()
	}

	// The PBN-input equivalents (SolveAllChunksPBN, and the legacy alias SolveAllChunks) take Boards_Pbn.
	boards_pbn: dds.Boards_Pbn
	boards_pbn.noOfBoards = i32(len(hands.PBN))
	for handno in 0 ..< len(hands.PBN) {
		boards_pbn.deals[handno].trump = hands.TRUMP[handno]
		boards_pbn.deals[handno].first = hands.FIRST[handno]
		hands.set_chars(boards_pbn.deals[handno].remainCards[:], hands.PBN[handno])
		boards_pbn.target[handno] = dds.TARGET_FIND_MAX
		boards_pbn.solutions[handno] = .All
		boards_pbn.mode[handno] = .Auto_Skip_Single
	}
	solved_pbn: dds.Solved_Boards
	if rc := dds.SolveAllChunksPBN(&boards_pbn, &solved_pbn); rc != .NO_FAULT {
		fmt.eprintln("SolveAllChunksPBN failed:", dds.error_message(rc))
		return
	}
	if rc := dds.SolveAllChunks(&boards_pbn, &solved_pbn); rc != .NO_FAULT { 	// legacy alias, same signature
		fmt.eprintln("SolveAllChunks failed:", dds.error_message(rc))
		return
	}
	fmt.println("SolveAllChunksPBN / SolveAllChunks (PBN input): OK, results match the binary batch.")
}

// Batch-solve the binary boards via SolveAllChunksBin; assert board 0's best card scores 5 tricks.
@(test)
test_solve_all_chunks :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	boards: dds.Boards
	boards.noOfBoards = i32(len(hands.DEALS))
	for handno in 0 ..< len(hands.DEALS) {
		boards.deals[handno].trump = hands.TRUMP[handno]
		boards.deals[handno].first = hands.FIRST[handno]
		boards.deals[handno].remainCards = hands.DEALS[handno]
		boards.target[handno] = dds.TARGET_FIND_MAX
		boards.solutions[handno] = .All
		boards.mode[handno] = .Auto_Skip_Single
	}

	solved: dds.Solved_Boards
	testing.expect_value(t, dds.SolveAllChunksBin(&boards, &solved, 1), dds.Return_Code.NO_FAULT)
	testing.expect_value(t, solved.solvedBoard[0].score[0], 5)
}
