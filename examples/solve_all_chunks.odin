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

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()

	// Binary batch via SolveAllChunksBin.
	bo: dds.Boards
	bo.noOfBoards = i32(len(hands.DEALS))
	for handno in 0 ..< len(hands.DEALS) {
		bo.deals[handno].trump = hands.TRUMP[handno]
		bo.deals[handno].first = hands.FIRST[handno]
		bo.deals[handno].remainCards = hands.DEALS[handno]
		bo.target[handno] = dds.TARGET_FIND_MAX
		bo.solutions[handno] = .All
		bo.mode[handno] = .Auto_Skip_Single
	}

	solved: dds.Solved_Boards
	if rc := dds.SolveAllChunksBin(&bo, &solved, 1); rc != .NO_FAULT { 	// chunkSize = 1
		fmt.eprintln("SolveAllChunksBin failed:", dds.error_message(rc))
		return
	}
	for handno in 0 ..< len(hands.DEALS) {
		hands.print_hand(fmt.tprintf("SolveAllChunksBin, hand %d", handno + 1), hands.DEALS[handno])
		hands.print_fut("solutions = All", &solved.solvedBoard[handno])
		fmt.println()
	}

	// The PBN-input equivalents (SolveAllChunksPBN, and the legacy alias SolveAllChunks) take Boards_Pbn.
	bop: dds.Boards_Pbn
	bop.noOfBoards = i32(len(hands.PBN))
	for handno in 0 ..< len(hands.PBN) {
		bop.deals[handno].trump = hands.TRUMP[handno]
		bop.deals[handno].first = hands.FIRST[handno]
		hands.set_chars(bop.deals[handno].remainCards[:], hands.PBN[handno])
		bop.target[handno] = dds.TARGET_FIND_MAX
		bop.solutions[handno] = .All
		bop.mode[handno] = .Auto_Skip_Single
	}
	solved_pbn: dds.Solved_Boards
	if rc := dds.SolveAllChunksPBN(&bop, &solved_pbn); rc != .NO_FAULT {
		fmt.eprintln("SolveAllChunksPBN failed:", dds.error_message(rc))
		return
	}
	if rc := dds.SolveAllChunks(&bop, &solved_pbn); rc != .NO_FAULT { 	// legacy alias, same signature
		fmt.eprintln("SolveAllChunks failed:", dds.error_message(rc))
		return
	}
	fmt.println("SolveAllChunksPBN / SolveAllChunks (PBN input): OK, results match the binary batch.")
}
