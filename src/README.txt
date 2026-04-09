//////////////////////////////////////////////////////////////////////

This directory contains software developed by Dr. Douglas Cheyne at the 
Hospital for Sick Children with the support of grants from the Canadian 
Institutes of Health Research and the Natural Sciences and Engineering 
Research Council of Canada.
 
This software is intended for RESEARCH PURPOSES ONLY and is not 
to be distributed without permission.

The beamformer images and virtual sensor calculations are based on algorithm described in:

   Cheyne D., Bakhtazad L. and Gaetz W. (2006) Spatiotemporal mapping of cortical activity accompanying 
   voluntary movements using an event-related beamforming approach.  Human Brain Mapping 27: 213-229.
and
   Cheyne D., Bostan AC., Gaetz W, Pang EW. (2007) Event-related beamforming: A robust method for 
   presurgical functional mapping using MEG. Clinical Neurophysiology, Vol 118 pp. 1691-1704.

Differential images based on modified version of SAM algorithm described in:

   Robinson, S. and Vrba J. (1999).  Functional neuroimaging by synthetic aperture magnetometry. 
   In: Nenonen J, Ilmoniemi RJ, Katila T, editors. 
   Biomag 2000: Proceedings of the 12th International Conference on Biomagnetism. p 302-305

Copyright (c) 2005 2010, 2026 Douglas O. Cheyne, PhD, All rights reserved.

/////////////////////////////////////////////////////////////////////

This C++ and C-mex code can be recompiled for Linux 64 bit (linux64)
or OS X for Intel (imac64) and ARM (amac64) processors as follows:

Step 1. make a clean compile of libraries as follows:

> cd brainwave/src/meglib
> make clean			# remove any existing object files
> make <platform>               # where <platform> = linux64 or imac64 or amac64

Step 2. compile mex functions 

> cd brainwave/mex
> make <platform>               # where <platform> = linux64 or imac64 or amac64
