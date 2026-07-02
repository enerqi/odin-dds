/*
   DDS, a bridge double dummy solver.

   Copyright (C) 2006-2014 by Bo Haglund /
   2014-2018 by Bo Haglund & Soren Hein.

   See LICENSE and README.
*/
package dds

import "core:strings"

when ODIN_OS == .Windows {
	// lib/dds.lib is a self-contained static archive (build it with `just build-lib`). Odin's
	// Windows entry point is mainCRTStartup + /defaultlib:libcmt, so C++ global constructors
	// (DDS's `sysdep` etc.) DO run before main -- a static lib links cleanly and needs no DLL.
	// IMPORTANT: DDS does its own one-time init (thread/TT-memory sizing, constant tables) from
	// DllMain, which only fires for the DLL build. When STATICALLY linked there is no DllMain, so
	// you MUST call `SetMaxThreads(0)` (or SetResources) once at startup before any other DDS
	// call, or the first call dereferences unsized state and crashes. See examples/smoke.odin.
	foreign import lib "lib/dds.lib"
} else when ODIN_OS == .Linux || ODIN_OS == .FreeBSD || ODIN_OS == .OpenBSD || ODIN_OS == .NetBSD {
	when !#exists("lib/dds.a") {
		#panic("Cannot find compiled dds libraries ./lib/dds.a. Compile by running `just build-lib`")
	}
	foreign import lib {"lib/dds.a", "system:stdc++", "system:pthread"}
} else when ODIN_OS == .Darwin {
	when !#exists("lib/darwin/dds.a") {
		#panic(
			"Cannot find compiled dds libraries ./lib/darwin/dds.a for ODIN_OS.Darwin. Compile by running `just build-lib`",
		)
	}
	foreign import lib {"lib/darwin/dds.a", "system:c++"}
} else {
	// Unknown OS. Fallback to searching for a global system installed library (also c.f. LD_LIBRARY_PATH)
	foreign import lib "system:dds"
}


// ---------------------------------------------------------------------------------------------------
// Odin-friendly wrapper types for DDS's integer-coded API. These are wired onto the generated struct
// fields / procedure parameters via `struct_field_overrides` and `procedure_type_overrides` in
// bindgen.sjson, so they survive `just bindgen`. All are `enum i32` / `u32`-backed to preserve the
// exact C layout (Odin's default enum backing is 64-bit `int`, which would NOT match `int`/`unsigned`).
// ---------------------------------------------------------------------------------------------------

// Card suit, 0..3 (no NT). "Suit encoding" for currentTrickSuit, Future_Tricks.suit, play traces, and
// the 2nd (suit) index of the Holding tables.
Suit :: enum i32 {
	Spades,
	Hearts,
	Diamonds,
	Clubs,
}

// Strain / denomination, 0..4 == Suit + NT. Used by Deal.trump, the resTable 1st index, and trumpFilter.
Strain :: enum i32 {
	Spades,
	Hearts,
	Diamonds,
	Clubs,
	NT,
}

// Seat leading / declaring a hand, 0..3. Deal.first, resTable 2nd index, dealer arguments.
Hand :: enum i32 {
	North,
	East,
	South,
	West,
}

// Vulnerability for par calculation (Par / CalcPar / DealerPar `vulnerable`, CalcAllTables `mode`).
Vulnerability :: enum i32 {
	None,
	Both,
	NS,
	EW,
}

// GOTCHA: contractType.denom uses a DIFFERENT ordering than `Suit`/`Strain` -- NT is 0 here, not 4.
// Verified against DDS `Par.cpp`: `denom_conv[5] = {4, 0, 1, 2, 3}` remaps this to the Suit encoding.
// A distinct enum stops it being silently mixed up with `Strain`.
Contract_Denom :: enum i32 {
	NT,
	Spades,
	Hearts,
	Diamonds,
	Clubs,
}

// Card rank, used only as the element set of `Holding`. "Holding encoding" is a bitmask where bit 2 is
// the deuce and bit 14 is the ace (bits 0 and 1 are always zero).
Rank :: enum u8 {
	_2    = 2,
	_3    = 3,
	_4    = 4,
	_5    = 5,
	_6    = 6,
	_7    = 7,
	_8    = 8,
	_9    = 9,
	Ten   = 10,
	Jack  = 11,
	Queen = 12,
	King  = 13,
	Ace   = 14,
}

// A holding: the set of ranks held in one suit, e.g. `Holding{.Ace, .King, .Queen}`. Backed by u32 to
// match DDS's `unsigned int` holding words (Deal.remainCards, ddTableDeal.cards, Future_Tricks.equals).
Holding :: bit_set[Rank;u32]

// Which side "starts the bidding" in a par result. parResults.parScore / parContractsString 1st index.
Side :: enum i32 {
	NS,
	EW,
}

// Declaring seat of a par contract, 0..5 (single hand or a partnership). contractType.seats.
Seat :: enum i32 {
	N,
	E,
	S,
	W,
	NS,
	EW,
}

// The multi-threading system. SetThreading `code` argument and DDS_Info.threading.
Threading :: enum i32 {
	None,
	WinAPI,
	OpenMP,
	GCD,
	Boost,
	STL,
	TBB,
	STLIMPL, // experimental (for_each)
	PPLIMPL, // experimental (for_each)
}

// SolveBoard `solutions`: how many solution cards to return.
Solutions :: enum i32 {
	One         = 1, // one card achieving the target (or the maximum)
	All_Optimal = 2, // all cards meeting (at least) the target
	All         = 3, // all cards, each with its score
}

// SolveBoard `mode`: transposition-table reuse behaviour. NOTE: this is NOT the CalcAllTables `mode`
// argument, which instead carries a Vulnerability (or -1 for "no par calc"; see NO_PAR_CALC).
Solve_Mode :: enum i32 {
	Auto_Skip_Single = 0, // TT auto-reused; skip the search when only one card (incl. equivalents) can be played
	Auto             = 1, // TT auto-reused; always search
	Reuse            = 2, // force TT reuse (caller guarantees it is safe)
}

// CalcAllTables / CalcAllTablesPBN `mode` sentinel meaning "do not perform a par calculation".
// Otherwise that `mode` argument is a Vulnerability value (its own encoding, hence left as i32).
NO_PAR_CALC :: i32(-1)

// SolveBoard `target` sentinel: solve for the maximum achievable number of tricks. Otherwise `target`
// is a plain trick count 0..13 (left as i32 -- it is a number, not a categorical value).
TARGET_FIND_MAX :: i32(-1)

// DDS_Info.system: the OS DDS thinks it is running on.
System :: enum i32 {
	Unknown,
	Windows,
	Cygwin,
	Linux,
	Apple,
}

// DDS_Info.compiler: the compiler DDS was built with.
Compiler :: enum i32 {
	Unknown,
	MSVC,
	Mingw,
	GPP,
	Clang,
}

// DDS_Info.constructor: how DDS auto-initializes (0 = none: static-linked, you must call SetMaxThreads).
Constructor :: enum i32 {
	None,
	DllMain,
	Unix,
}

// DDS function return code. Hand-written as `enum i32` (NOT via enumify_macros, which would back it with
// 64-bit `int` and break the C `int` return ABI). Mirrors the RETURN_* constants. Overridden onto every
// int-returning DDS function via procedure_type_overrides. RETURN_NO_FAULT (== .NO_FAULT) is success.
Return_Code :: enum i32 {
	NO_FAULT        = 1,
	UNKNOWN_FAULT   = -1,
	ZERO_CARDS      = -2,
	TARGET_TOO_HIGH = -3,
	DUPLICATE_CARDS = -4,
	TARGET_WRONG_LO = -5,
	TARGET_WRONG_HI = -7,
	SOLNS_WRONG_LO  = -8,
	SOLNS_WRONG_HI  = -9,
	TOO_MANY_CARDS  = -10,
	SUIT_OR_RANK    = -12,
	PLAYED_CARD     = -13,
	CARD_COUNT      = -14,
	THREAD_INDEX    = -15,
	MODE_WRONG_LO   = -16,
	MODE_WRONG_HI   = -17,
	TRUMP_WRONG     = -18,
	FIRST_WRONG     = -19,
	PLAY_FAULT      = -98,
	PBN_FAULT       = -99,
	TOO_MANY_BOARDS = -101,
	THREAD_CREATE   = -102,
	THREAD_WAIT     = -103,
	THREAD_MISSING  = -104,
	NO_SUIT         = -201,
	TOO_MANY_TABLES = -202,
	CHUNK_SIZE      = -301,
}


// Wrapper around ErrorMessage: returns the human-readable text for a DDS return code as an Odin string
// (cloned into `allocator`; caller frees). See the RETURN_* / TEXT_* constants.
error_message :: proc(code: Return_Code, allocator := context.allocator) -> string {
	buf: [80]i8
	ErrorMessage(code, &buf)
	return strings.clone(string(cstring(rawptr(&buf[0]))), allocator)
}


/* Version 2.9.0. Allowing for 2 digit minor versions */
DDS_VERSION :: 20900
DDS_HANDS :: 4
DDS_SUITS :: 4
DDS_STRAINS :: 5
MAXNOOFBOARDS :: 200
MAXNOOFTABLES :: 40

// Error codes. See interface document for more detail.
// Call ErrorMessage(code, line[]) to get the text form in line[].

// Success.
RETURN_NO_FAULT :: 1
TEXT_NO_FAULT :: "Success"

// Currently happens when fopen() fails or when AnalyseAllPlaysBin()
// get a different number of boards in its first two arguments.
RETURN_UNKNOWN_FAULT :: -1
TEXT_UNKNOWN_FAULT :: "General error"

// SolveBoard()
RETURN_ZERO_CARDS :: -2
TEXT_ZERO_CARDS :: "Zero cards"

// SolveBoard()
RETURN_TARGET_TOO_HIGH :: -3
TEXT_TARGET_TOO_HIGH :: "Target exceeds number of tricks"

// SolveBoard()
RETURN_DUPLICATE_CARDS :: -4
TEXT_DUPLICATE_CARDS :: "Cards duplicated"

// SolveBoard()
RETURN_TARGET_WRONG_LO :: -5
TEXT_TARGET_WRONG_LO :: "Target is less than -1"

// SolveBoard()
RETURN_TARGET_WRONG_HI :: -7
TEXT_TARGET_WRONG_HI :: "Target is higher than 13"

// SolveBoard()
RETURN_SOLNS_WRONG_LO :: -8
TEXT_SOLNS_WRONG_LO :: "Solutions parameter is less than 1"

// SolveBoard()
RETURN_SOLNS_WRONG_HI :: -9
TEXT_SOLNS_WRONG_HI :: "Solutions parameter is higher than 3"

// SolveBoard(), self-explanatory.
RETURN_TOO_MANY_CARDS :: -10
TEXT_TOO_MANY_CARDS :: "Too many cards"

// SolveBoard()
RETURN_SUIT_OR_RANK :: -12
TEXT_SUIT_OR_RANK :: "currentTrickSuit or currentTrickRank has wrong data"

// SolveBoard
RETURN_PLAYED_CARD :: -13
TEXT_PLAYED_CARD :: "Played card also remains in a hand"

// SolveBoard()
RETURN_CARD_COUNT :: -14
TEXT_CARD_COUNT :: "Wrong number of remaining cards in a hand"

// SolveBoard()
RETURN_THREAD_INDEX :: -15
TEXT_THREAD_INDEX :: "Thread index is not 0 .. maximum"

// SolveBoard()
RETURN_MODE_WRONG_LO :: -16
TEXT_MODE_WRONG_LO :: "Mode parameter is less than 0"

// SolveBoard()
RETURN_MODE_WRONG_HI :: -17
TEXT_MODE_WRONG_HI :: "Mode parameter is higher than 2"

// SolveBoard()
RETURN_TRUMP_WRONG :: -18
TEXT_TRUMP_WRONG :: "Trump is not in 0 .. 4"

// SolveBoard()
RETURN_FIRST_WRONG :: -19
TEXT_FIRST_WRONG :: "First is not in 0 .. 2"

// AnalysePlay*() family of functions.
// (a) Less than 0 or more than 52 cards supplied.
// (b) Invalid suit or rank supplied.
// (c) A played card is not held by the right player.
RETURN_PLAY_FAULT :: -98
TEXT_PLAY_FAULT :: "AnalysePlay input error"

// Returned from a number of places if a PBN string is faulty.
RETURN_PBN_FAULT :: -99
TEXT_PBN_FAULT :: "PBN string error"

// SolveBoard() and AnalysePlay*()
RETURN_TOO_MANY_BOARDS :: -101
TEXT_TOO_MANY_BOARDS :: "Too many boards requested"

// Returned from multi-threading functions.
RETURN_THREAD_CREATE :: -102
TEXT_THREAD_CREATE :: "Could not create threads"

// Returned from multi-threading functions when something went
// wrong while waiting for all threads to complete.
RETURN_THREAD_WAIT :: -103
TEXT_THREAD_WAIT :: "Something failed waiting for thread to end"

// Tried to set a multi-threading system that is not present in DLL.
RETURN_THREAD_MISSING :: -104
TEXT_THREAD_MISSING :: "Multi-threading system not present"

// CalcAllTables*()
RETURN_NO_SUIT :: -201
TEXT_NO_SUIT :: "Denomination filter vector has no entries"

// CalcAllTables*()
RETURN_TOO_MANY_TABLES :: -202
TEXT_TOO_MANY_TABLES :: "Too many DD tables requested"

// SolveAllChunks*()
RETURN_CHUNK_SIZE :: -301
TEXT_CHUNK_SIZE :: "Chunk size is less than 1"

Future_Tricks :: struct {
	nodes:  i32,
	cards:  i32,
	suit:   [13]Suit,
	rank:   [13]i32,
	equals: [13]Holding,
	score:  [13]i32,
}

Deal :: struct {
	trump:            Strain,
	first:            Hand,
	currentTrickSuit: [3]Suit,
	currentTrickRank: [3]i32,
	remainCards:      [Hand][Suit]Holding,
}

Deal_Pbn :: struct {
	trump:            Strain,
	first:            Hand,
	currentTrickSuit: [3]Suit,
	currentTrickRank: [3]i32,
	remainCards:      [80]i8,
}

Boards :: struct {
	noOfBoards: i32,
	deals:      [200]Deal,
	target:     [200]i32,
	solutions:  [200]Solutions,
	mode:       [200]Solve_Mode,
}

Boards_Pbn :: struct {
	noOfBoards: i32,
	deals:      [200]Deal_Pbn,
	target:     [200]i32,
	solutions:  [200]Solutions,
	mode:       [200]Solve_Mode,
}

Solved_Boards :: struct {
	noOfBoards:  i32,
	solvedBoard: [200]Future_Tricks,
}

Table_Deal :: struct {
	cards: [Hand][Suit]Holding,
}

Table_Deals :: struct {
	noOfTables: i32,
	deals:      [200]Table_Deal,
}

Table_Deal_Pbn :: struct {
	cards: [80]i8,
}

Table_Deals_Pbn :: struct {
	noOfTables: i32,
	deals:      [200]Table_Deal_Pbn,
}

Table_Results :: struct {
	resTable: [Strain][Hand]i32,
}

Tables_Res :: struct {
	noOfBoards: i32,
	results:    [200]Table_Results,
}

Par_Results :: struct {
	/* index = 0 is NS view and index = 1
	is EW view. By 'view' is here meant
	which side that starts the bidding. */
	parScore:           [Side][16]i8,
	parContractsString: [Side][128]i8,
}

All_Par_Results :: struct {
	presults: [40]Par_Results,
}

Par_Results_Dealer :: struct {
	/* number: Number of contracts yielding the par score.
	score: Par score for the specified dealer hand.
	contracts:  Par contract text strings.  The first contract
	is in contracts[0], the last one in contracts[number-1].
	The detailed text format is is given in the DLL interface
	document.
	*/
	number:    i32,
	score:     i32,
	contracts: [10][10]i8,
}

Contract_Type :: struct {
	underTricks: i32, /* 0 = make 1-13 = sacrifice */
	overTricks:  i32, /* 0-3, e.g. 1 for 4S + 1. */
	level:       i32, /* 1-7 */
	denom:       Contract_Denom, /* 0 = No Trumps, 1 = trump Spades, 2 = trump Hearts,
				  3 = trump Diamonds, 4 = trump Clubs */
	seats:       Seat, /* One of the cases N, E, W, S, NS, EW;
				   0 = N 1 = E, 2 = S, 3 = W, 4 = NS, 5 = EW */
}

Par_Results_Master :: struct {
	score:     i32, /* Sign according to the NS view */
	number:    i32, /* Number of contracts giving the par score */
	contracts: [10]Contract_Type, /* Par contracts */
}

Par_Text_Results :: struct {
	parText: [Side][128]i8, /* Short text for par information, e.g.
				Par -110: EW 2S EW 2D+1 */
	equal:   bool, /* true in the normal case when it does not matter who
			starts the bidding. Otherwise, false. */
}

Play_Trace_Bin :: struct {
	number: i32,
	suit:   [52]i32,
	rank:   [52]i32,
}

Play_Trace_Pbn :: struct {
	number: i32,
	cards:  [106]i8,
}

Solved_Play :: struct {
	number: i32,
	tricks: [53]i32,
}

Play_Traces_Bin :: struct {
	noOfBoards: i32,
	plays:      [200]Play_Trace_Bin,
}

Play_Traces_Pbn :: struct {
	noOfBoards: i32,
	plays:      [200]Play_Trace_Pbn,
}

Solved_Plays :: struct {
	noOfBoards: i32,
	solved:     [200]Solved_Play,
}

DDS_Info :: struct {
	// Version 2.8.0 has 2, 8, 0 and a string of 2.8.0
	major, minor, patch: i32,
	versionString:       [10]i8,

	// Currently 0 = unknown, 1 = Windows, 2 = Cygwin, 3 = Linux, 4 = Apple
	system:              System,

	// We know 32 and 64-bit systems.
	numBits:             i32,

	// Currently 0 = unknown, 1 = Microsoft Visual C++, 2 = mingw,
	// 3 = GNU g++, 4 = clang
	compiler:            Compiler,

	// Currently 0 = none, 1 = DllMain, 2 = Unix-style
	constructor:         Constructor,
	numCores:            i32,

	// Currently
	// 0 = none,
	// 1 = Windows (native),
	// 2 = OpenMP,
	// 3 = GCD,
	// 4 = Boost,
	// 5 = STL,
	// 6 = TBB,
	// 7 = STLIMPL (for_each), experimental only
	// 8 = PPLIMPL (for_each), experimental only
	threading:           Threading,

	// The actual number of threads configured
	noOfThreads:         i32,

	// This will break if there are > 128 threads...
	// The string is of the form LLLSSS meaning 3 large TT memories
	// and 3 small ones.
	threadSizes:         [128]i8,
	systemString:        [1024]i8,
}

@(default_calling_convention = "c")
foreign lib {
	SetMaxThreads :: proc(userThreads: i32 = 0) ---
	SetThreading :: proc(code: Threading) -> Return_Code ---
	SetResources :: proc(maxMemoryMB: i32, maxThreads: i32 = 0) ---
	FreeMemory :: proc() ---
	SolveBoard :: proc(dl: Deal, target: i32, solutions: Solutions, mode: Solve_Mode, futp: ^Future_Tricks, threadIndex: i32 = 0) -> Return_Code ---
	SolveBoardPBN :: proc(dlpbn: Deal_Pbn, target: i32, solutions: Solutions, mode: Solve_Mode, futp: ^Future_Tricks, thrId: i32 = 0) -> Return_Code ---
	CalcDDtable :: proc(tableDeal: Table_Deal, tablep: ^Table_Results) -> Return_Code ---
	CalcDDtablePBN :: proc(tableDealPBN: Table_Deal_Pbn, tablep: ^Table_Results) -> Return_Code ---
	CalcAllTables :: proc(dealsp: ^Table_Deals, mode: i32, trumpFilter: ^[Strain]b32, resp: ^Tables_Res, presp: ^All_Par_Results) -> Return_Code ---
	CalcAllTablesPBN :: proc(dealsp: ^Table_Deals_Pbn, mode: i32, trumpFilter: ^[Strain]b32, resp: ^Tables_Res, presp: ^All_Par_Results) -> Return_Code ---
	SolveAllBoards :: proc(bop: ^Boards_Pbn, solvedp: ^Solved_Boards) -> Return_Code ---
	SolveAllBoardsBin :: proc(bop: ^Boards, solvedp: ^Solved_Boards) -> Return_Code ---
	SolveAllChunks :: proc(bop: ^Boards_Pbn, solvedp: ^Solved_Boards, chunkSize: i32 = 1) -> Return_Code ---
	SolveAllChunksBin :: proc(bop: ^Boards, solvedp: ^Solved_Boards, chunkSize: i32 = 1) -> Return_Code ---
	SolveAllChunksPBN :: proc(bop: ^Boards_Pbn, solvedp: ^Solved_Boards, chunkSize: i32 = 1) -> Return_Code ---
	Par :: proc(tablep: ^Table_Results, presp: ^Par_Results, vulnerable: Vulnerability) -> Return_Code ---
	CalcPar :: proc(tableDeal: Table_Deal, vulnerable: Vulnerability, tablep: ^Table_Results, presp: ^Par_Results) -> Return_Code ---
	CalcParPBN :: proc(tableDealPBN: Table_Deal_Pbn, tablep: ^Table_Results, vulnerable: Vulnerability, presp: ^Par_Results) -> Return_Code ---
	SidesPar :: proc(tablep: ^Table_Results, sidesRes: ^[2]Par_Results_Dealer, vulnerable: Vulnerability) -> Return_Code ---
	DealerPar :: proc(tablep: ^Table_Results, presp: ^Par_Results_Dealer, dealer: Hand, vulnerable: Vulnerability) -> Return_Code ---
	DealerParBin :: proc(tablep: ^Table_Results, presp: ^Par_Results_Master, dealer: Hand, vulnerable: Vulnerability) -> Return_Code ---
	SidesParBin :: proc(tablep: ^Table_Results, sidesRes: ^[2]Par_Results_Master, vulnerable: Vulnerability) -> Return_Code ---
	ConvertToDealerTextFormat :: proc(pres: ^Par_Results_Master, resp: cstring) -> Return_Code ---
	ConvertToSidesTextFormat :: proc(pres: ^Par_Results_Master, resp: ^Par_Text_Results) -> Return_Code ---
	AnalysePlayBin :: proc(dl: Deal, play: Play_Trace_Bin, solved: ^Solved_Play, thrId: i32 = 0) -> Return_Code ---
	AnalysePlayPBN :: proc(dlPBN: Deal_Pbn, playPBN: Play_Trace_Pbn, solvedp: ^Solved_Play, thrId: i32 = 0) -> Return_Code ---
	AnalyseAllPlaysBin :: proc(bop: ^Boards, plp: ^Play_Traces_Bin, solvedp: ^Solved_Plays, chunkSize: i32 = 1) -> Return_Code ---
	AnalyseAllPlaysPBN :: proc(bopPBN: ^Boards_Pbn, plpPBN: ^Play_Traces_Pbn, solvedp: ^Solved_Plays, chunkSize: i32 = 1) -> Return_Code ---
	GetDDSInfo :: proc(info: ^DDS_Info) ---
	ErrorMessage :: proc(code: Return_Code, line: ^[80]i8) ---
}
