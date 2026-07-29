// Port of external/dds/examples/SolveAllBoards.cpp.
//
// SolveAllBoards is the batched form of SolveBoard: it solves many positions (each with its own
// target / solutions / mode) in a single parallel call, returning a Future_Tricks per board. Use it
// instead of a SolveBoard loop when you have many positions to solve -- DDS schedules them across
// threads for a big speed-up. Here each board is a full deal asking for all optimal cards (.All).
//
// Inputs (dds.Boards_Pbn): noOfBoards, then per board a PBN deal plus its own target[]/solutions[]/
// mode[] arrays. Output (dds.Solved_Boards): solvedBoard[i] is the Future_Tricks for board i.
//
// Run:  just run solve_all_boards
package main

import "core:fmt"
import "core:testing"

import dds ".."
import "hands"

main :: proc() {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	boards: dds.Boards_Pbn
	boards.noOfBoards = i32(len(hands.PBN))
	for handno in 0 ..< len(hands.PBN) {
		boards.deals[handno].trump = hands.TRUMP[handno]
		boards.deals[handno].first = hands.FIRST[handno]
		hands.set_chars(boards.deals[handno].remainCards[:], hands.PBN[handno])
		boards.target[handno] = dds.TARGET_FIND_MAX
		boards.solutions[handno] = .All
		boards.mode[handno] = .Auto_Skip_Single
	}

	solved: dds.Solved_Boards
	if rc := dds.SolveAllBoards(&boards, &solved); rc != .NO_FAULT {
		fmt.eprintln("SolveAllBoards failed:", dds.error_message(rc))
		return
	}

	for handno in 0 ..< len(hands.PBN) {
		hands.print_pbn_hand(fmt.tprintf("SolveAllBoards, hand %d", handno + 1), hands.PBN[handno])
		hands.print_future_tricks("solutions = All (every card + score)", &solved.solvedBoard[handno])
		fmt.println()
	}
}

// Batch-solve all boards; assert board 0's best card scores 5 tricks (matches solve_board).
@(test)
test_solve_all_boards :: proc(t: ^testing.T) {
	dds.SetMaxThreads()
	defer dds.FreeMemory()

	boards: dds.Boards_Pbn
	boards.noOfBoards = i32(len(hands.PBN))
	for handno in 0 ..< len(hands.PBN) {
		boards.deals[handno].trump = hands.TRUMP[handno]
		boards.deals[handno].first = hands.FIRST[handno]
		hands.set_chars(boards.deals[handno].remainCards[:], hands.PBN[handno])
		boards.target[handno] = dds.TARGET_FIND_MAX
		boards.solutions[handno] = .All
		boards.mode[handno] = .Auto_Skip_Single
	}

	solved: dds.Solved_Boards
	testing.expect_value(t, dds.SolveAllBoards(&boards, &solved), dds.Return_Code.NO_FAULT)
	testing.expect_value(t, solved.solvedBoard[0].score[0], 5)
}
