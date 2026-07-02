# Build DDS static library and stage it into ../lib/
# Mirrors src/build.cmd (Windows) but for Linux and macOS.
#
# Threading: STL-only on Linux (no libgomp dep for static consumers),
# GCD+STL on macOS (GCD is the native Apple threading; no extra flags).
# No Boost, no OpenMP -- keeps the static lib dependency-free.
#
# No LTO: Odin uses lld-link / ld, not g++ -- LTO objects are non-portable.
# ffunction-sections: lets the linker dead-strip unused DDS symbols.

UNAME_S := $(shell uname -s)

DDS_SRC  := ../external/dds/src
OBJ_DIR  := ../external/dds/build/obj

SOURCES := \
	dds.cpp dump.cpp ABsearch.cpp ABstats.cpp CalcTables.cpp DealerPar.cpp \
	File.cpp Init.cpp LaterTricks.cpp Memory.cpp Moves.cpp Par.cpp \
	PlayAnalyser.cpp PBN.cpp QuickTricks.cpp Scheduler.cpp SolveBoard.cpp \
	SolverIF.cpp System.cpp ThreadMgr.cpp Timer.cpp TimerGroup.cpp \
	TimerList.cpp TimeStat.cpp TimeStatList.cpp TransTableS.cpp TransTableL.cpp

ifeq ($(UNAME_S),Darwin)
CXX      := clang++
THREADING := -DDDS_THREADS_GCD -DDDS_THREADS_STL
LIB_OUT  := ../lib/darwin/dds.a
LIB_DIR  := ../lib/darwin
else
CXX      := g++
THREADING := -DDDS_THREADS_STL
LIB_OUT  := ../lib/dds.a
LIB_DIR  := ../lib
endif

CXXFLAGS := -O3 -std=c++20 -ffunction-sections \
	-Wall -Wno-unused -Wno-unknown-pragmas -Wno-format -Wno-long-long \
	$(THREADING)

OBJS := $(patsubst %.cpp,$(OBJ_DIR)/%.o,$(SOURCES))

.PHONY: all clean

all: $(LIB_OUT)

$(LIB_OUT): $(OBJS) | $(LIB_DIR)
	ar rcs $@ $^
	rm -rf $(OBJ_DIR)

$(OBJ_DIR)/%.o: $(DDS_SRC)/%.cpp | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR):
	mkdir -p $@

$(LIB_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR) $(LIB_OUT)
