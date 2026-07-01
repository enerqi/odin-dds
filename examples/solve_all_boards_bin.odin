// Example for SolveAllBoardsBin (DDS 2.9.1 addition; added "for symmetry" with SolveAllBoards).
//
// SolveAllBoardsBin is SolveAllBoards with BINARY input: the batched, parallel SolveBoard over many
// positions, but the deals are given as dds.Boards (remainCards as Holding bit_sets) instead of
// dds.Boards_Pbn (PBN strings). Reach for it when your deals are already in binary form and you don't
// want to stringify them into PBN just to batch-solve. Everything else -- per-board target/solutions/
// mode, and the dds.Solved_Boards output (a Future_Tricks per board) -- matches SolveAllBoards.
//
// Unlike the SolveAllChunks* variants, SolveAllBoardsBin does not expose chunkSize; DDS picks the
// scheduling. See solve_all_boards.odin (PBN input) and solve_all_chunks.odin (chunkSize control).
//
// Run:  just run solve_all_boards_bin
package main

import "core:fmt"
import "core:testing"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

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
	if rc := dds.SolveAllBoardsBin(&bo, &solved); rc != .NO_FAULT {
		fmt.eprintln("SolveAllBoardsBin failed:", dds.error_message(rc))
		return
	}

	for handno in 0 ..< len(hands.DEALS) {
		hands.print_hand(fmt.tprintf("SolveAllBoardsBin, hand %d", handno + 1), hands.DEALS[handno])
		hands.print_fut("solutions = All", &solved.solvedBoard[handno])
		fmt.println()
	}
}

// Batch-solve the binary boards via SolveAllBoardsBin; assert board 0's best card scores 5 tricks
// (matches solve_board / solve_all_boards / solve_all_chunks for the same board).
@(test)
test_solve_all_boards_bin :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

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
	testing.expect_value(t, dds.SolveAllBoardsBin(&bo, &solved), dds.Return_Code.NO_FAULT)
	testing.expect_value(t, solved.solvedBoard[0].score[0], 5)
}
