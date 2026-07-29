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

	boards: dds.Boards
	boards.noOfBoards = i32(len(hands.DEALS))
	for cards, handno in hands.DEALS {
		boards.deals[handno].trump = hands.TRUMP[handno]
		boards.deals[handno].first = hands.FIRST[handno]
		boards.deals[handno].remainCards = cards
		boards.target[handno] = dds.TARGET_FIND_MAX
		boards.solutions[handno] = .All
		boards.mode[handno] = .Auto_Skip_Single
	}

	solved: dds.Solved_Boards
	if rc := dds.SolveAllBoardsBin(&boards, &solved); rc != .NO_FAULT {
		fmt.eprintln("SolveAllBoardsBin failed:", dds.error_message(rc))
		return
	}

	for cards, handno in hands.DEALS {
		hands.print_hand(fmt.tprintf("SolveAllBoardsBin, hand %d", handno + 1), cards)
		hands.print_future_tricks("solutions = All (every card + score)", &solved.solvedBoard[handno])
		fmt.println()
	}
}

// Batch-solve the binary boards via SolveAllBoardsBin; assert board 0's best card scores 5 tricks
// (matches solve_board / solve_all_boards / solve_all_chunks for the same board).
@(test)
test_solve_all_boards_bin :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	boards: dds.Boards
	boards.noOfBoards = i32(len(hands.DEALS))
	for cards, handno in hands.DEALS {
		boards.deals[handno].trump = hands.TRUMP[handno]
		boards.deals[handno].first = hands.FIRST[handno]
		boards.deals[handno].remainCards = cards
		boards.target[handno] = dds.TARGET_FIND_MAX
		boards.solutions[handno] = .All
		boards.mode[handno] = .Auto_Skip_Single
	}

	solved: dds.Solved_Boards
	testing.expect_value(t, dds.SolveAllBoardsBin(&boards, &solved), dds.Return_Code.NO_FAULT)
	testing.expect_value(t, solved.solvedBoard[0].score[0], 5)
}
