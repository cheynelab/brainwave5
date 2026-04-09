# makefile for MEGlib
# D. Cheyne, Feb, 2010
# modified for ctf lib by Zhengkai Chen and D. Cheyne, May, 2012….
#
# modified Feb 4, 2013 D. Cheyne
# - combined all sources and headers into separate folders for easier sharing of header files….
#
# modified Sept, 2020 D. Cheyne
# - ctflib doesn't need link to pthreads, compiling for 64 bit Windows should work using MSYS2 and MinGW 64 bit compiler (see notes)
#
# New meglib library Fall 2025 - combined ctflib and bwlib
# * note Windows support not maintained but compile statement kept for future use ...
# can be copied as local compiled library into other projects - git version updated here

CC = g++
CFLAGS = -c -Wno-deprecated -Wno-deprecated-declarations -fPIC
CCwin64 = g++ -static-libgcc -static-libstdc++ -c -Wno-deprecated -fPIC
MEG_LIB = ./sources
LDFLAGS = -fopenmp -mthreads
LDFL = -lm -lgomp -lole32 -luuid -lcomctl32 -lgdi32 -lwsock32

win64:
	make part3 CXXFLAGS="-O3 -ffast-math -funroll-all-loops -fpeel-loops -ftracer -funswitch-loops -funit-at-a-time"
	$(CCwin64) -o $(OBJS) $^ $(LDFLAGS) $(LDFL)
	ld -r $(OBJS3) -o ctflib_win64.o

linux64:
	make part1 CXXFLAGS="-O3 -march=x86-64 -ffast-math -funroll-all-loops -fpeel-loops -ftracer -funswitch-loops -funit-at-a-time -fPIC"
	make part2 CXXFLAGS="-O1 -march=x86-64 -ffast-math -funroll-all-loops -fpeel-loops -ftracer -funswitch-loops -funit-at-a-time -fPIC"
	ld -r $(OBJS1) $(OBJS2) -o meglib_glx64.o
	
imac64:
	make part1 CXXFLAGS="-target x86_64-apple-macos10.12 -O3 -Wno-deprecated -Wno-deprecated-declarations -fPIC"
	make part2 CXXFLAGS="-target x86_64-apple-macos10.12 -O1 -Wno-deprecated -Wno-deprecated-declarations -fPIC"
	ld -r $(OBJS1) $(OBJS2) -o meglib_maci64.o
	
amac64:
	make part1 CXXFLAGS="-target arm64-apple-macos11 -Wno-deprecated -Wno-deprecated-declarations -O3 -fPIC"
	make part2 CXXFLAGS="-target arm64-apple-macos11 -Wno-deprecated -Wno-deprecated-declarations -O1 -fPIC"
	ld -r $(OBJS1) $(OBJS2) -o meglib_maca64.o

# List object files

OBJS1 =	$(MEG_LIB)/vectorMath.o \
	$(MEG_LIB)/complex_math.o \
	$(MEG_LIB)/BWFilter.o \
	$(MEG_LIB)/sourceUtils.o \
	$(MEG_LIB)/bwlib.o

# for Linux and Mac compile datasetUtils.cc without O3 optimization - creates problems with NtoH routines
OBJS2 =	$(MEG_LIB)/datasetUtils.o \
	$(MEG_LIB)/fileUtils.o
	
part1: $(OBJS1)
part2: $(OBJS2)

clean:
	rm $(OBJS1) $(OBJS2)
