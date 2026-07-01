// Shared example data + print helpers, ported from external/dds/examples/hands.{h,cpp}. Imported by the
// single-file examples in ../ . Three canned deals are provided in Odin-native form.
//
// NOTE: DDS's C `holdings[handno][suit][hand]` is transposed relative to `deal.remainCards[hand][suit]`;
// the C examples transpose on assignment. We store DEALS already in [Hand][Suit] order, so an example can
// assign a whole board directly:  dl.remainCards = hands.DEALS[i]
package hands

import "core:fmt"
import "core:strings"
import "core:testing"

import dds "../.."

// The three example boards, [deal][Hand][Suit] -> Holding.
DEALS := [3][dds.Hand][dds.Suit]dds.Holding {
	0 = {
		.North = {
			.Spades = {.Queen, .Jack, ._6},
			.Hearts = {.King, ._6, ._5, ._2},
			.Diamonds = {.Jack, ._8, ._5},
			.Clubs = {.Ten, ._9, ._8},
		},
		.East = {
			.Spades = {._8, ._7, ._3},
			.Hearts = {.Jack, ._9, ._7},
			.Diamonds = {.Ace, .Ten, ._7, ._6, ._4},
			.Clubs = {.Queen, ._4},
		},
		.South = {
			.Spades = {.King, ._5},
			.Hearts = {.Ten, ._8, ._3},
			.Diamonds = {.King, .Queen, ._9},
			.Clubs = {.Ace, ._7, ._6, ._5, ._2},
		},
		.West = {
			.Spades = {.Ace, .Ten, ._9, ._4, ._2},
			.Hearts = {.Ace, .Queen, ._4},
			.Diamonds = {._3, ._2},
			.Clubs = {.King, .Jack, ._3},
		},
	},
	1 = {
		.North = {
			.Spades = {.Ace, .King, ._9, ._6},
			.Hearts = {.King, .Queen, ._8},
			.Diamonds = {.Ace, ._9, ._8},
			.Clubs = {.King, ._6, ._3},
		},
		.East = {
			.Spades = {.Queen, .Jack, .Ten, ._5, ._4, ._3, ._2},
			.Hearts = {.Ten},
			.Diamonds = {._6},
			.Clubs = {.Queen, .Jack, ._8, ._2},
		},
		.South = {
			.Spades   = {}, // void
			.Hearts   = {.Jack, ._9, ._7, ._5, ._4, ._3},
			.Diamonds = {.King, ._7, ._5, ._3, ._2},
			.Clubs    = {._9, ._4},
		},
		.West = {
			.Spades = {._8, ._7},
			.Hearts = {.Ace, ._6, ._2},
			.Diamonds = {.Queen, .Jack, .Ten, ._4},
			.Clubs = {.Ace, .Ten, ._7, ._5},
		},
	},
	2 = {
		.North = {
			.Spades = {._7, ._3},
			.Hearts = {.Queen, .Jack, .Ten},
			.Diamonds = {.Ace, .Queen, ._5, ._4},
			.Clubs = {.Ten, ._7, ._5, ._2},
		},
		.East = {
			.Spades = {.Queen, .Ten, ._6},
			.Hearts = {._8, ._7, ._6},
			.Diamonds = {.King, .Jack, ._9},
			.Clubs = {.Ace, .Queen, ._8, ._4},
		},
		.South = {
			.Spades = {._5},
			.Hearts = {.Ace, ._9, ._5, ._4, ._3, ._2},
			.Diamonds = {._7, ._6, ._3, ._2},
			.Clubs = {.King, ._6},
		},
		.West = {
			.Spades = {.Ace, .King, .Jack, ._9, ._8, ._4, ._2},
			.Hearts = {.King},
			.Diamonds = {.Ten, ._8},
			.Clubs = {.Jack, ._9, ._3},
		},
	},
}

// Per-deal metadata used by the various example programs.
TRUMP := [3]dds.Strain{.Spades, .NT, .Spades}
FIRST := [3]dds.Hand{.North, .East, .South}
DEALER := [3]dds.Hand{.North, .East, .North}
VUL := [3]dds.Vulnerability{.None, .NS, .None}

PBN := [3]string {
	"N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
	"E:QJT5432.T.6.QJ82 .J97543.K7532.94 87.A62.QJT4.AT75 AK96.KQ8.A98.K63",
	"N:73.QJT.AQ54.T752 QT6.876.KJ9.AQ84 5.A95432.7632.K6 AKJ9842.K.T8.J93",
}

@(private)
RANKS_HIGH_TO_LOW := [?]dds.Rank{.Ace, .King, .Queen, .Jack, .Ten, ._9, ._8, ._7, ._6, ._5, ._4, ._3, ._2}
@(private)
RANK_CHAR := [dds.Rank]u8 {
	._2    = '2',
	._3    = '3',
	._4    = '4',
	._5    = '5',
	._6    = '6',
	._7    = '7',
	._8    = '8',
	._9    = '9',
	.Ten   = 'T',
	.Jack  = 'J',
	.Queen = 'Q',
	.King  = 'K',
	.Ace   = 'A',
}
@(private)
SUIT_CHAR := [dds.Suit]u8 {
	.Spades   = 'S',
	.Hearts   = 'H',
	.Diamonds = 'D',
	.Clubs    = 'C',
}
@(private)
STRAIN_STR := [dds.Strain]string {
	.Spades   = " S",
	.Hearts   = " H",
	.Diamonds = " D",
	.Clubs    = " C",
	.NT       = "NT",
}

// Render one suit holding high-to-low, e.g. Holding{.King,.Six,.Five,.Two} -> "K652" (or "-" if void).
// Cloned into `allocator` (defaults to the temp allocator).
holding_string :: proc(h: dds.Holding, allocator := context.temp_allocator) -> string {
	b := strings.builder_make(allocator)
	for r in RANKS_HIGH_TO_LOW {
		if r in h {
			strings.write_byte(&b, RANK_CHAR[r])
		}
	}
	if strings.builder_len(b) == 0 {
		strings.write_byte(&b, '-')
	}
	return strings.to_string(b)
}

// Print all four hands of a board, one hand per line.
print_hand :: proc(title: string, cards: [dds.Hand][dds.Suit]dds.Holding) {
	fmt.println(title)
	for hand in dds.Hand {
		fmt.printf("  %-5v ", hand)
		for suit in dds.Suit {
			fmt.printf(" %c:%s", SUIT_CHAR[suit], holding_string(cards[hand][suit]))
		}
		fmt.println()
	}
}

// Print a double-dummy table: tricks for each strain (rows) and declarer (columns).
print_table :: proc(res: ^dds.Table_Results) {
	fmt.println("       N  E  S  W")
	for strain in dds.Strain {
		fmt.printf("  %s ", STRAIN_STR[strain])
		for hand in dds.Hand {
			fmt.printf(" %2d", res.resTable[strain][hand])
		}
		fmt.println()
	}
}


// The played cards for each of the three deals, as a PBN-style card string (suit letter + rank,
// concatenated, no separators). playNo in the C examples == len/2. The binary play traces are derived
// from these by `play_trace_bin`, so we don't duplicate the 3x52 suit/rank integer tables.
PLAY_PBN := [3]string {
	"CTC4CACJH8H4HKH9D5DAD9D2S7S5S2SQD8D4DQD3H3HAH6H7C3C8CQC2S3SKSAS6HQH5HJHTCKC9D6C5S4SJS8C6DJ",
	"SQD2S8SAHKHTH3H2HQS2H4H6H8D6HJHAS7SKS4C4D8C2DKD4H9C5S6S3H7C7C3S5H5CTD9STD3DQDAC8S9SJC9DTCQD5CAC6DJCKCJD7",
	"HAHKHQH7D7D8DAD9C5CAC6C3",
}

@(private)
suit_from_char :: proc(c: u8) -> i32 {
	switch c {
	case 'S':
		return 0
	case 'H':
		return 1
	case 'D':
		return 2
	case 'C':
		return 3
	}
	return -1
}

@(private)
rank_from_char :: proc(c: u8) -> i32 {
	switch c {
	case '2' ..= '9':
		return i32(c - '0')
	case 'T':
		return 10
	case 'J':
		return 11
	case 'Q':
		return 12
	case 'K':
		return 13
	case 'A':
		return 14
	}
	return -1
}

// Parse a PLAY_PBN card string into a binary play trace (Suit encoding + rank 2..14).
play_trace_bin :: proc(pbn: string) -> dds.Play_Trace_Bin {
	p: dds.Play_Trace_Bin
	n: i32 = 0
	for i := 0; i + 1 < len(pbn); i += 2 {
		p.suit[n] = suit_from_char(pbn[i])
		p.rank[n] = rank_from_char(pbn[i + 1])
		n += 1
	}
	p.number = n
	return p
}

// A PBN play trace just carries the raw card string plus a count.
play_trace_pbn :: proc(pbn: string) -> dds.Play_Trace_Pbn {
	p: dds.Play_Trace_Pbn
	p.number = i32(len(pbn) / 2)
	set_chars(p.cards[:], pbn)
	return p
}

// Copy an Odin string into a fixed C char (i8) buffer, null-terminated (the DDS *PBN structs use these).
set_chars :: proc(dst: []i8, s: string) {
	n := min(len(s), len(dst) - 1)
	for i in 0 ..< n {
		dst[i] = i8(s[i])
	}
	dst[n] = 0
}

// View a null-terminated C char (i8) buffer as an Odin string (borrowed; valid while the buffer lives).
chars_string :: proc(buf: []i8) -> string {
	return string(cstring(rawptr(&buf[0])))
}

// Print a PBN-encoded hand (we just echo the deal string rather than re-parsing it into a diagram).
print_pbn_hand :: proc(title: string, pbn: string) {
	fmt.println(title)
	fmt.printfln("  %s", pbn)
}

// Print a par result: the par score and contracts for each side.
print_par :: proc(pres: ^dds.Par_Results) {
	for side in dds.Side {
		fmt.printfln(
			"  %v: score %s  contracts %s",
			side,
			chars_string(pres.parScore[side][:]),
			chars_string(pres.parContractsString[side][:]),
		)
	}
}

@(private)
CONTRACT_DENOM_STR := [dds.Contract_Denom]string {
	.NT       = "NT",
	.Spades   = "S",
	.Hearts   = "H",
	.Diamonds = "D",
	.Clubs    = "C",
}

// Format one structured par contract, e.g. "4S by N", "3NT by NS -2" (a 2-trick sacrifice), "4H by E +1".
// NOTE: Contract_Denom has its own ordering (NT = 0), distinct from Suit/Strain -- see the bindings.
contract_string :: proc(c: dds.Contract_Type) -> string {
	base := fmt.tprintf("%d%s by %v", c.level, CONTRACT_DENOM_STR[c.denom], c.seats)
	if c.underTricks > 0 {
		return fmt.tprintf("%s -%d", base, c.underTricks)
	}
	if c.overTricks > 0 {
		return fmt.tprintf("%s +%d", base, c.overTricks)
	}
	return base
}

// Print a structured (binary) par result: the par score and its contracts as Contract_Type structs.
print_par_master :: proc(pres: ^dds.Par_Results_Master) {
	fmt.printfln("  Par score (NS view) %d, %d contract(s):", pres.score, pres.number)
	for i in 0 ..< pres.number {
		fmt.printfln("    %s", contract_string(pres.contracts[i]))
	}
}

// Print a two-sided par text result (from ConvertToSidesTextFormat).
print_par_text :: proc(t: ^dds.Par_Text_Results) {
	fmt.printfln("  NS view: %s", chars_string(t.parText[.NS][:]))
	fmt.printfln("  EW view: %s", chars_string(t.parText[.EW][:]))
	fmt.printfln("  side-independent: %v", t.equal)
}

// Print a dealer-oriented par result: score and the list of par contracts.
print_dealer_par :: proc(pres: ^dds.Par_Results_Dealer) {
	fmt.printfln("  Score %d, %d contract(s):", pres.score, pres.number)
	for i in 0 ..< pres.number {
		fmt.printfln("    %s", chars_string(pres.contracts[i][:]))
	}
}

// Print a futureTricks result: each returned card (suit+rank), its score (tricks), and the lower
// equivalent cards (`equals`, a Holding).
print_fut :: proc(title: string, fut: ^dds.Future_Tricks) {
	fmt.println(title)
	for i in 0 ..< fut.cards {
		rank := dds.Rank(u8(fut.rank[i]))
		fmt.printfln(
			"  %c%c  score %d  equals %s",
			SUIT_CHAR[fut.suit[i]],
			RANK_CHAR[rank],
			fut.score[i],
			holding_string(fut.equals[i]),
		)
	}
}

// Print a solved play trace: the double-dummy trick total after each card played.
print_solved_play :: proc(solved: ^dds.Solved_Play) {
	fmt.printf("  DD tricks after each card:")
	for i in 0 ..< solved.number {
		fmt.printf(" %d", solved.tricks[i])
	}
	fmt.println()
}


// ---- Shared expected values for the example @(test) procs (see ../smoke.odin etc.) ----

// The known double-dummy table for board 0 (DEALS[0] == PBN[0]): resTable[strain][declarer] tricks.
// The several CalcDDtable-family examples all solve this same board, so they assert against this.
DDTABLE_0 := [dds.Strain][dds.Hand]i32 {
	.Spades   = {.North = 5, .East = 8, .South = 5, .West = 8},
	.Hearts   = {.North = 6, .East = 6, .South = 6, .West = 6},
	.Diamonds = {.North = 5, .East = 7, .South = 5, .West = 7},
	.Clubs    = {.North = 7, .East = 5, .South = 7, .West = 5},
	.NT       = {.North = 6, .East = 6, .South = 6, .West = 6},
}

// Assert a full double-dummy table cell-by-cell against `want`. Used by the example tests.
expect_table :: proc(t: ^testing.T, got: ^dds.Table_Results, want: [dds.Strain][dds.Hand]i32) {
	for strain in dds.Strain {
		for hand in dds.Hand {
			testing.expect_value(t, got.resTable[strain][hand], want[strain][hand])
		}
	}
}
