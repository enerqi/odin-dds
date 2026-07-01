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
		#panic("Cannot find compiled dds libraries ./lib/dds.a. Compile by running `make -C src`")
	}
	foreign import lib "lib/dds.a"
} else when ODIN_OS == .Darwin {
	when !#exists("lib/darwin/dds.a") {
		#panic(
			"Cannot find compiled dds libraries ./lib/darwin/dds.a for ODIN_OS.Darwin. Compile by running `make -C src`",
		)
	}
	foreign import lib "lib/darwin/dds.a"
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
