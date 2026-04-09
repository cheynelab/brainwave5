# new makefile for compiling BW mex functions locally
# VERSION 5.3 - combined previous bw_libraries into one local meglib library in /src directory

MEG_LIB = ../src/meglib

# updated Nov, 2016 for compilation on VM

# Matlab compiler version on Mac 10.14
# using XCode 10 Apple LLVM version 10.0.0 (clang-1000.11.45.2)
#
mex_imac64 = /Applications/MATLAB_R2023a.app/bin/mex

# added compile statements for Mac ARM chip - requires recompiled libraries! 
mex_amac64 = /Applications/MATLAB_R2023b.app/bin/mex

# Matlab compiler for CentOS 6.0 on VMware
mex_linux = /usr/local/MATLAB/R2014b/bin/mex

linux64:
	$(mex_linux) bw_geom2res4.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_CTFGetParams.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_CTFGetHeader.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_CTFGetSensors.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_CTFGetChannelData.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_CTFGetChannelLabels.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_CTFEpochDs.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_CTFChangeHeadPos.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_getCTFData.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_filter.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_combineDs.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_kit2res4.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_concatenateDs.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_fitDipole.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_CTFNewDs.cc $(MEG_LIB)/meglib_glx64.o

	$(mex_linux) bw_CTFGetAverage.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_makeVS.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_makeEventRelated.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_makeDifferential.cc $(MEG_LIB)/meglib_glx64.o
	$(mex_linux) bw_makeCrossTalkImages.cc $(MEG_LIB)/meglib_glx64.o
	
	$(mex_linux) bw_computeFaceNormals.cc
	$(mex_linux) trilinear.cpp
	mv *.mexa64 ../

imac64:
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_geom2res4.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_CTFGetParams.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' -DMX_COMPAT_32 bw_CTFGetHeader.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_CTFGetSensors.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_CTFGetChannelData.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_CTFGetChannelLabels.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_CTFEpochDs.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_CTFChangeHeadPos.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_getCTFData.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_filter.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_combineDs.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_kit2res4.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_concatenateDs.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_fitDipole.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_CTFNewDs.cc $(MEG_LIB)/meglib_maci64.o
	
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_CTFGetAverage.cc $(MEG_LIB)/meglib_maci64.o $(BW_LIB)/bwlib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_makeVS.cc $(MEG_LIB)/meglib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_makeEventRelated.cc $(MEG_LIB)/meglib_maci64.o $(BW_LIB)/bwlib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_makeDifferential.cc $(MEG_LIB)/meglib_maci64.o $(BW_LIB)/bwlib_maci64.o
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_makeCrossTalkImages.cc $(MEG_LIB)/meglib_maci64.o $(BW_LIB)/bwlib_maci64.o

	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' bw_computeFaceNormals.cc
	$(mex_imac64) CXXFLAGS='-target x86_64-apple-macos10.9 -Wno-deprecated-declarations' trilinear.cpp

	mv *.mexmaci64 ../

amac64:
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_geom2res4.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_CTFGetParams.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' -DMX_COMPAT_32 bw_CTFGetHeader.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_CTFGetSensors.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_CTFGetChannelData.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_CTFGetChannelLabels.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_CTFEpochDs.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_CTFChangeHeadPos.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_getCTFData.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_filter.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_combineDs.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_kit2res4.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_concatenateDs.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_fitDipole.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_CTFNewDs.cc $(MEG_LIB)/meglib_maca64.o

	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_CTFGetAverage.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_makeVS.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_makeEventRelated.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_makeDifferential.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_makeCrossTalkImages.cc $(MEG_LIB)/meglib_maca64.o
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' bw_computeFaceNormals.cc
	$(mex_amac64) CXXFLAGS='-target arm64-apple-macos11 -Wno-deprecated-declarations' trilinear.cpp

	mv *.mexmaca64 ../
