/////////////////////////////////////////////////////////////////////////////////////////////////////////
//		bwUtils.cc
//
//      ** this replaces sourceUtils for beamformer software
//
//		(c) Douglas O. Cheyne, 2005-2010  All rights reserved.
// 
//		Revision history
//		Feb 17, 2005			D. Cheyne
//
//      November 2005           -- added flag to header for LSAM
//      
//      December 2005           -- added multiple sphere options for forward solutions
//      December 18, 2005       -- working version for multisphere
//                              -- removed passing of origin to bb2vox since this is not necessary always defined
//                      
//      December 19, 2005       -- moved getCovariance and makeFilterWeights routine (as function ) to here
// 
//      December 21             -- added multiple new routines to do makeLCMV etc
//      
//      January  11, 2006       -- now pass normalList to set selected voxel weights to zero.  Don't save .vox file for weights.
//                              -- added routine to do sorting of double arrays.
//      Feb 18, 2006            -- changed way that vox files are created -- fixed rounding problem for odd sized voxels
//                              -- removed old routines
//      March 15, 2006          -- added routine to compute beamformer weights using SAM method
//
//      ************* major changes ***********
//		Feb 26, 2010			-- new version, moved everything from old sourceUtils to main library directory, includes multithreading of LCMV weights.
//
//      April 6, 2010          -- now passes cov and icov to weights routine which is simplified and can compute direction on separate data covariance
//
//      May 10, 2010			-- added computeVS function for mex functions - adapted from makeVS.cc which was stand-alone C program.
//
//      July 27, 2010			-- added ability to write and read data average and covariance data from disk files to speed up makeVS.
//
//      ************* major changes ***********
//      May 11, 2012			- this is beamformer parts of sourceUtils now called bwUtils and part of bwlib 
//                              - note the dependencies on routines in the new ctflib which contains old MEGlib stuff. 
//                              - also moved multithreaded covariance calculations here (was in computeCovariance.cc in the old dataSetUtils lib) 
//		Oct 9, 2012				- changed computeEventRelated to take vector of latencies instead of range and step.
//      Feb 3, 2013             - renamed bwlib and moved up one folder
//      March 14, 2013          - added new function to compute differential images from two different datasets...
//      Jan, 2025               - added functions to return forward solution matrix from weight calculation and generate CTF and PSF images.
//      June, 2025              - recompiled for brainwave5
//      Nov, 2025               - moved to combined library with ctflib renamed "meglib"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <sys/stat.h>
#include <time.h>
#include "unistd.h"

#if defined _WIN64 || defined _WIN32
	#include <pthread.h>//pthread library for windows, added by zhengkai
#endif

// header now in headers folder
#include "../headers/bwlib.h"

// some global variables for large data arrays, names must not conflict with other global arrays in ctflib... 
//
double 		**bw_trialData; 
double 		**bw_sensorData;		// this gets allocated while bw_trialData is in use! 
double		***bw_weight_array;
double      ***bw_forward_array;

int nBytesRead;

double  getBWLibVersion()
{
    return(CTFLIB_VERSION);
}    // unused var change to force git update....

vectorCart psi2cart( vectorCart axis, double angle )
{
	vectorCart	result;
	vectorCart	v;
   	double     	pie = acos(-1.0);
	
	// This routine converts a local angle ("angle") in the tangential plane at the location 
	// pointed to by an arbitrary axis ("axis") to a unit vector in the reference coordinate system. 
	// This is same as defining the local angle as a rotation of a unit vector around
	// the z axis (where zero degrees points in the +x direction) and then rotating the z-axis
	// to line up with the arbitrary axis.  When angle psi is zero it points downwards
	// along the line of longitude and if it is 90 degrees it points leftwards along line of latitude
	// 
	vectorSph 	axisSph;
	vectorSph 	psiSph;
	vectorCart 	psiCart;
	
	// convert local angle to unit vector in x-y plane (i.e., relative to z axis)
	psiSph.declination = pie / 2.0;  
	psiSph.radius = 1.0;
	psiSph.azimuth = Deg2Rad(angle);
	psiCart = spherical2cartesian( psiSph );

	// now perform rotation of z axis onto the arbitrary axis
	// 
	axisSph = cartesian2spherical( axis );

	double alpha = axisSph.declination;
	double beta = axisSph.azimuth;		

	// rotate CCW about y axis by alpha
	double x = (psiCart.x * cos(alpha) ) + ( psiCart.z * sin(alpha) );
	double y = psiCart.y;
	double z = (psiCart.x * -sin(alpha) ) + (psiCart.z * cos(alpha) );

	// rotate CCW about z axis by beta
	v.x = ( x * cos(beta)) - ( y * sin(beta));
	v.y = ( x * sin(beta)) + ( y * cos(beta));
	v.z = z;

	result = unitVector(v); 	// make sure we return as unit vector
	

	return (result);
}

////////////////////////////////////////////////////////////////////////
// beamformer weight calculation.  
//  multi-threaded code by Maher Quraan, 2008
//
//   D. Cheyne, March, 2010, 
// - addded option to do vector or scalar weights in same routine
// - removed global variables except for static pointers required
//   for multi-thread code - added g_ prefix for those....
//


void *wtsThread(void *threadArg)
{
	
	dip_params	dipole;
	vectorCart	radial;
	vectorCart	orient;
	vectorCart	orthog;
	
	const int	NDIR=2;

	double		minRadius = 0.5;
	bool		showPercentDone = true;
	double		voxelRadius;
	double		denom[NDIR][NDIR];
	double		idenom[NDIR][NDIR];
	double		power2D[NDIR][NDIR];
	double		noise2D[NDIR][NDIR];
	
	bool 		computeMagnetic = false;
	bool 		useDewar = false;
	
	thread_wts_t *threadData = (thread_wts_t *) threadArg;
	int threadID = threadData->threadID;
	int voxelStart = threadData->voxelStart;
	int voxelEnd = threadData->voxelEnd;

	// *** Memory allocation   
	//
	double *w = (double *)malloc( sizeof(double) * g_numSensors );
	if (w == NULL)
    {
		printf("Memory allocation failed for w array\n");
		abort();
    }
	
	double **h = (double **)malloc( sizeof(double*) * NDIR );
	if (h == NULL)
    {
		printf("Memory allocation failed for forward array\n");
		abort();
    }
	for (int i = 0; i <NDIR ; i++)
    {
		h[i] = (double *)malloc( sizeof(double) * g_numSensors );
		if ( h[i] == NULL)
		{
			printf( "Memory allocation failed for forward array\n" );
			abort();
		}
    }
	
	double **wts = (double **)malloc( sizeof(double*) * NDIR );
	if (wts == NULL)
    {
		printf("Memory allocation failed for wts array\n");
		abort();
    }
	for (int i = 0; i <NDIR ; i++)
    {
		wts[i] = (double *)malloc( sizeof(double) * g_numSensors );
		if ( wts[i] == NULL)
		{
			printf( "Memory allocation failed for wts array\n" );
			abort();
		}
    }
	
	double **num = (double **)malloc( sizeof(double*) * NDIR );
	if (num == NULL)
    {
		printf("Memory allocation failed for temp array\n");
		abort();
    }
	for (int i = 0; i < NDIR; i++)
    {
		num[i] = (double *)malloc( sizeof(double) * g_numSensors );
		if ( num[i] == NULL)
		{
			printf( "Memory allocation failed for temp array\n" );
			abort();
		}
    }

	for (int voxel=voxelStart; voxel<voxelEnd; voxel++)
    {
		
		// get dipole location for this voxel
		dipole.xpos = g_voxelListPtr[voxel].x;
		dipole.ypos = g_voxelListPtr[voxel].y;
		dipole.zpos = g_voxelListPtr[voxel].z;
		
		// Get distance of voxel from center of sphere for min radius check
		radial.x = dipole.xpos - g_sphereX;
		radial.y = dipole.ypos - g_sphereY;
		radial.z = dipole.zpos - g_sphereZ;
		voxelRadius = vectorLength( radial );	
		
		dipole.xori = g_normalListPtr[voxel].x;
		dipole.yori = g_normalListPtr[voxel].y;
		dipole.zori = g_normalListPtr[voxel].z;
		
		// removed flagging for zero normal 
		//		double len = dipole.xori + dipole.yori + dipole.zori;
		//		if ( voxelRadius < minRadius || len == 0.0 )
		
		if ( voxelRadius < minRadius )
		{
			for(int j=0; j<NDIR; j++)
			{
				for(int k=0; k<g_numSensors; k++)
				{
					wts[j][k] = 0.0;
				}
			}
		}
		else 
		{
			if (g_numWeightVectors == 1 && !g_optimizeOrientation)
			{
				// if computing fixed orientation weights, computation is simple...

				dipole.moment = 1.0e9;   // need to set this value!
				
				// Compute the forward solution for the optimal or fixed dipole orientation
				if ( !computeForwardSolution( g_dsParams, dipole, h[0], false, g_gradientOrder, computeMagnetic, useDewar) )
				{
					printf("computeForwardSolution() returned error\n");
					abort();
				}

				// compute one-dimensional (scalar) weights 
				// get BC'
				for (int j=0; j<g_numSensors; j++)
				{
					w[j] = 0.0;
					for (int k=0; k<g_numSensors; k++)
						w[j] += h[0][k] * g_iCovArray[j][k];
				}
				//  get denom =  BC'B 
				double scalar_denom = 0.0;
				for (int k=0; k<g_numSensors; k++)
					scalar_denom += w[k] * h[0][k];
				
				// get weights = BC' / BC'B
				for(int k=0; k<g_numSensors; k++)
					wts[0][k] = w[k]/ scalar_denom;
							
			}
			else
			{ 
				///////////////////////////////////////////////////////
				//  D. Cheyne, March, 2010
				//  compute vector beamformer weights for m sensors
				//  using standard LCMV beamformer equation...
				//  h = 2 x m forward matrix for 2 orthogonal dipoles in sphere (psi = 0 and 90 degrees)
				//  iCov = inverse of m x m covariance matrix (defined as static global!)
				//  wts = h' iCov  * inv[h' iCov h]
				//////////////////////////////////////////////////////				
	
				// get a unit vector that defines the radial direction for this voxel
				// using dipole position vector.  
				
				radial.x = dipole.xpos - g_sphereX;
				radial.y = dipole.ypos - g_sphereY;
				radial.z = dipole.zpos - g_sphereZ;
				radial = unitVector(radial);
								
				// define dipole orientation as zero local angle
				// note that this is the angle that optimal orientation
				// is relative to.  If these angles are rotated from zero, must also
				// rotate the angle returned by the eigendecomposition below...
				//
				orient = psi2cart(radial,0.0);
				orient = unitVector(orient);
				dipole.xori = orient.x;
				dipole.yori = orient.y;
				dipole.zori = orient.z;	
				dipole.moment = 1.0e9;
				
				if ( !computeForwardSolution( g_dsParams, dipole, h[0], false, g_gradientOrder, computeMagnetic, useDewar ) )
				{
					printf("computeForwardSolution() returned error\n");
					abort();
				}
				
				// now get forward solution for orthogonal source                         
				orient = psi2cart(radial, 90.0);
				orient = unitVector(orient);
				dipole.xori = orient.x;
				dipole.yori = orient.y;
				dipole.zori = orient.z;	
				dipole.moment = 1.0e9;
				
				if ( !computeForwardSolution( g_dsParams, dipole, h[1], false, g_gradientOrder, computeMagnetic, useDewar ) )
				{
					printf("computeForwardSolution() returned error\n");
					abort();
				}
								
				// compute non-noise normalized vector weights 
				// W = h' iCov * inv[h' iCov h]

				//   numerator = h' * iCov
				for (int i=0; i<NDIR; i++)
				{
					for (int j=0; j<g_numSensors; j++)
					{
						num[i][j] = 0.0;
						for (int k=0; k<g_numSensors; k++)
							num[i][j] += h[i][k] * g_iCovArray[j][k];
					}
				}
				//  denom =  inv[h' iCov h] = inv [num * h ]
				for (int i=0; i<NDIR; i++)
				{
					for (int j=0; j<NDIR; j++)
					{
						denom[i][j] = 0.0;
						for (int k=0; k<g_numSensors; k++)
							denom[i][j] += h[i][k] * num[j][k];
					}
				}
				
				invertMatrix2D(denom);

				for (int i=0; i<NDIR; i++)
				{
					for (int j=0; j<g_numSensors; j++)
					{			
						wts[i][j] = (num[0][j] * denom[0][i] ) + (num[1][j] * denom[1][i]);
					}
				}
				
				// if computing vector weights we are done...
				
				if (g_optimizeOrientation)
				{
					// get the optimal dipole orientation using eigen-decomposition
					// and recompute weights for that direction only...
					// get 2 x 2 power matrix P = W'CW
					// ** note we now use the passed covariance array that can be different iCovArray
					
					// W'C
					// 
					for (int i=0; i<NDIR; i++)
					{
						for (int j=0; j<g_numSensors; j++)
						{
							num[i][j] = 0.0;
							for (int k=0; k<g_numSensors; k++)
								num[i][j] += wts[i][k] * g_CovArray[j][k];
						}
					}
					// (W'C) x W
					for (int i=0; i<NDIR; i++)
					{
						for (int j=0; j<NDIR; j++)
						{
							denom[i][j] = 0.0;
							for (int k=0; k<g_numSensors; k++)
								denom[i][j] += wts[i][k] * num[j][k];
						}
					}
					
					// normalize W'CW to unit length - Borgiotti-Kaplan beamformer
					// not clear it makes a difference with or without normalization
					
					// get inverse of W'W
					for (int i=0; i<NDIR; i++)
					{
						for (int j=0; j<NDIR; j++)
						{
							noise2D[i][j] = 0.0;
							for (int k=0; k<g_numSensors; k++)
								noise2D[i][j] += wts[j][k] * wts[i][k];
						}
					}
					invertMatrix2D(noise2D);
					
					for (int i=0; i<NDIR; i++)
					{
						for (int j=0; j<NDIR; j++)
						{
							power2D[i][j] = 0.0;
							for (int k=0; k<2; k++)
								power2D[i][j] += denom[k][j] * noise2D[i][k];
						}
					}

//					// w/o weight-vector normalization
//					for (int i=0; i<NDIR; i++)
//					{
//						for (int j=0; j<NDIR; j++)
//						{
//							power2D[i][j] = denom[i][j];
//						}
//					}
					
					// get dominant orientation from power 
					// compute eigenvalues and eigenvectors
					// Note this assumes a symmetric NDIRxNDIR matrix A = [a b; b c]
					
					double lambda1;
					double lambda2;
					double x1;
					double x2;
					double y1;
					double y2;
					
					// get eigenvalues of NDIR x NDIR matrix
					double a = power2D[0][0];
					double b = power2D[0][1];    // asssumes always mat2D[0][1] = mat2D[1][0] !
					double c = power2D[1][1];
					
					double disc = sqrt((a-c)*(a-c)+4*b*b)/2.0;                            
					lambda1 = (a+c)/2.0 + disc;
					lambda2 = (a+c)/2.0 - disc;
					// compute weights for best local angle 
					// this is given by eigenvector[x1,x2] for largest eigenvalue.  
					// this eigenvector is component of dipole 1 (always = local angle of 0 degrees)
					// thus the local angle is the azimuth angle of this vector w.r.t dipole 1
					
					// get eigenVector corresponding to max eigenValue
					x1 = -b;
					if ( lambda1 > lambda2)
						x2 = a-lambda1;
					else
						x2 = a-lambda2;
					double mag = sqrt(x1*x1 + x2*x2);  
					x1 /= mag;  
					x2 /= mag;
					
					vectorCart cvec;
					vectorSph  svec;
					cvec.x = x1;
					cvec.y = x2;
					cvec.z = 0.0;
					
					svec = cartesian2spherical(cvec);
					double t = svec.azimuth;
					
					double angle = Rad2Deg(t);
					
					// this is optimal angle RELATIVE to direction of the dipoles
					// keep angle in range from 0 to 180 degrees
					if (angle > 180 )
						angle -= 180.0;
										
					orient = psi2cart(radial, angle);
					orient = unitVector(orient);
					
					// this is optimal orientation in x, y z coordinates
					
					dipole.xori = orient.x;
					dipole.yori = orient.y;
					dipole.zori = orient.z;                       
					dipole.moment = 1.0e9;
	
					// now compute the forward solution
					// and weights for the optimal dipole orientation
					if ( !computeForwardSolution( g_dsParams, dipole, h[0], false, g_gradientOrder, computeMagnetic, useDewar) )
					{
						printf("computeForwardSolution() returned error\n");
						abort();
					}
					
					for (int j=0; j<g_numSensors; j++)
					{
						w[j] = 0.0;
						for (int k=0; k<g_numSensors; k++)
							w[j] += h[0][k] * g_iCovArray[j][k];
					}
					//  get denom =  BC'B 
					double scalar_denom = 0.0;
					for (int k=0; k<g_numSensors; k++)
						scalar_denom += w[k] * h[0][k];
					
					// get weights = BC' / BC'B
					for(int k=0; k<g_numSensors; k++)
						wts[0][k] = w[k]/ scalar_denom;
				
					// return the optimized dipole orientation in normalListPtr
					g_normalListPtr[voxel].x = dipole.xori;
					g_normalListPtr[voxel].y = dipole.yori;
					g_normalListPtr[voxel].z = dipole.zori;
					
				}
			}			
			
		} // next voxel for this thread
		
		// Lock the mutex and update shared variables
		
		pthread_mutex_lock(&wtsArrayMutex);
		
		// Increment total voxels computed so far
		
		
		 //Save weights for this voxel in big static global array
		 //to pass back to calling function

		for (int i=0; i<g_numWeightVectors; i++)
			for (int k=0;k<g_numSensors;k++)
				g_wtsArrayPtr[i][voxel][k] = wts[i][k];

		pthread_mutex_unlock(&wtsArrayMutex);
		
		g_totVoxels++;
		if ( showPercentDone )
			printPercentDone( g_totVoxels, g_numVoxels);
		
		
    }	// next voxel;
	
	
	// ***** 
	// Free all memory
	
	for (int i = 0; i < NDIR; i++)
    {
		free(wts[i]);
		free(num[i]);
		free(h[i]);	
    }
	free(wts);
	free(num);
	free(h);
	free(w);
    pthread_exit((void *) 0);
    
    return 0;
}

// compute scalar LCMV weights using passed dataset params and covariance array
// note that passing program has already computed covariance array and set sphere origins
// in dsParams so don't need to know specifics about bandpass or head model 
// compute mean sphere origin from all sensors which will have either multi-spheres or single sphere
// origin.  Added voxel flags to turn specified voxels on/off.  NormalList not currently used but keep
// for future use as constraint.
//
bool computeBeamformerWeights(         
						char *dsName,
						ds_params & dsParams,
						double ***weight_array,
						int numWeightVectors,
						double **covArray,
						double **icovArray,
						vectorCart *voxelList,
						vectorCart *normalList,
						int numVoxels,
						bool optimizeOrientation)
{
	
	if (weight_array == NULL)
	{
		printf("null pointer for weight_array in computeBeamformerWeights...\n");
		return (false);
	}

	// initialize static globals for variable passing during threading
	// these are defined in sourceUtils.h 

	if ( !readMEGResFile( dsName, g_dsParams) )	
    {
	  printf("Could not open MEG resource in dataset [%s]\n", dsName);
	  return(false);
    }
	g_dsNamePtr = dsName;
	g_dsParams = dsParams;

	g_voxelListPtr = voxelList;
	g_normalListPtr = normalList;

	g_numSensors = g_dsParams.numSensors;
	g_numVoxels = numVoxels;	
	g_numWeightVectors = numWeightVectors;
	g_wtsArrayPtr = weight_array;

	g_optimizeOrientation = optimizeOrientation;		
	g_gradientOrder = g_dsParams.gradientOrder;

	g_CovArray = covArray;
	g_iCovArray = icovArray;
	
	g_sphereX = 0.0;
	g_sphereY = 0.0;
	g_sphereZ = 0.0;
	int sensorCount = 0;
	for (int i=0; i < g_dsParams.numChannels; i++)
    {
		// get mean sphere -- include balancing refs
		if ( g_dsParams.channel[i].isSensor || g_dsParams.channel[i].isBalancingRef ) 
		{
			g_sphereX += g_dsParams.channel[i].sphereX;
			g_sphereY += g_dsParams.channel[i].sphereY;
			g_sphereZ += g_dsParams.channel[i].sphereZ;
			sensorCount++;
		}
    }
	g_sphereX /= (double)sensorCount;
	g_sphereY /= (double)sensorCount;                
	g_sphereZ /= (double)sensorCount;
	printf("Using mean sphere origin: %g, %g, %g\n", g_sphereX, g_sphereY, g_sphereZ); 
	

	// threading starts here
	// ********************** 

	// threading code from M. Quraan
	
	// int *voxelID[NUM_WTS_THREADS];
	
	// Set thread attributes to be joinable
	
	pthread_attr_t attr;
	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
	
	// Initialize the mutex
    
	pthread_mutex_init(&wtsArrayMutex, NULL);
			

	// Determine boundaries for each thread
	
	int voxelsPerThread;
	if( numVoxels < NUM_WTS_THREADS )
    {
		voxelsPerThread = 1;
    }
	else
    {
		voxelsPerThread = numVoxels/NUM_WTS_THREADS;
    }
	int voxelStart = 0;
	int voxelEnd = voxelsPerThread;
	if( voxelEnd > numVoxels) voxelEnd = numVoxels;
	
	thread_wts_t wtsThreadData[NUM_WTS_THREADS];
	
	if (numWeightVectors == 1)
		printf("computing scalar weights...\n");
	else
		printf("computing vector weights...\n");

	if (g_optimizeOrientation)
		printf("optimizing source orientation using eigendecomposition ...\n");
			   
	// Calculate the weights
	
	int numActualThreads = 0;
	g_totVoxels = 0;
	
	for (int iThread=0; iThread<NUM_WTS_THREADS; iThread++)
    {
		numActualThreads++;
		wtsThreadData[iThread].threadID = iThread;
		wtsThreadData[iThread].voxelStart = voxelStart;
		wtsThreadData[iThread].voxelEnd = voxelEnd;
		
		//printf("iThread = %d, voxelStart = %d, voxelEnd = %d\n", iThread, voxelStart, voxelEnd-1);
		
		int rc = pthread_create(&wtsThreads[iThread], &attr, wtsThread, (void *) &wtsThreadData[iThread]);
		if (rc) 
		{
			printf("ERROR; return code from pthread_create() is %d\n", rc);
			return( false);
		}
		
		voxelStart += voxelsPerThread;
		if( voxelStart >= numVoxels ) 
			break;
		voxelEnd += voxelsPerThread;
		if( voxelEnd > numVoxels ) 
			voxelEnd = numVoxels;
		// if( (numVoxels-voxelEnd) < voxelsPerThread ) voxelEnd = numVoxels;
		if( iThread==(NUM_WTS_THREADS-2) ) 
			voxelEnd = numVoxels;
    }
	
	// Join all threads
	
	for (int iThread=0; iThread<numActualThreads; iThread++)
    {
		int status;
		int rc = pthread_join(wtsThreads[iThread], (void **)&status);
		if (rc)
		{
			printf("ERROR return code from pthread_join() is %d\n", rc);
			return ( false);
		}
		//printf("Completed join with thread %d status= %d\n",iThread, status);
		
    }
		
	// Free threading resources

//	pthread_mutex_unlock(&wtsArrayMutex);
	pthread_attr_destroy(&attr);
	pthread_mutex_destroy(&wtsArrayMutex);
	
	printf("\n...done\n");
	
	return(true);
}

void *wtsThreadNew(void *threadArg)
{
    
    dip_params    dipole;
    vectorCart    radial;
    vectorCart    orient;
    vectorCart    orthog;
    
    const int     NDIR=2;

    double        minRadius = 0.5;
    bool          showPercentDone = true;
    double        voxelRadius;
    double        denom[NDIR][NDIR];
    double        idenom[NDIR][NDIR];
    double        power2D[NDIR][NDIR];
    double        noise2D[NDIR][NDIR];
    
    bool         computeMagnetic = false;
    bool         useDewar = false;
    
    thread_wts_t *threadData = (thread_wts_t *) threadArg;
    int threadID = threadData->threadID;
    int voxelStart = threadData->voxelStart;
    int voxelEnd = threadData->voxelEnd;

    // *** Memory allocation
    //
    double *w = (double *)malloc( sizeof(double) * g_numSensors );
    if (w == NULL)
    {
        printf("Memory allocation failed for w array\n");
        abort();
    }
    
    double **h = (double **)malloc( sizeof(double*) * NDIR );
    if (h == NULL)
    {
        printf("Memory allocation failed for forward array\n");
        abort();
    }
    for (int i = 0; i <NDIR ; i++)
    {
        h[i] = (double *)malloc( sizeof(double) * g_numSensors );
        if ( h[i] == NULL)
        {
            printf( "Memory allocation failed for forward array\n" );
            abort();
        }
    }
    
    double **wts = (double **)malloc( sizeof(double*) * NDIR );
    if (wts == NULL)
    {
        printf("Memory allocation failed for wts array\n");
        abort();
    }
    for (int i = 0; i <NDIR ; i++)
    {
        wts[i] = (double *)malloc( sizeof(double) * g_numSensors );
        if ( wts[i] == NULL)
        {
            printf( "Memory allocation failed for wts array\n" );
            abort();
        }
    }
    
    double **num = (double **)malloc( sizeof(double*) * NDIR );
    if (num == NULL)
    {
        printf("Memory allocation failed for temp array\n");
        abort();
    }
    for (int i = 0; i < NDIR; i++)
    {
        num[i] = (double *)malloc( sizeof(double) * g_numSensors );
        if ( num[i] == NULL)
        {
            printf( "Memory allocation failed for temp array\n" );
            abort();
        }
    }

    for (int voxel=voxelStart; voxel<voxelEnd; voxel++)
    {
        
        // get dipole location for this voxel
        dipole.xpos = g_voxelListPtr[voxel].x;
        dipole.ypos = g_voxelListPtr[voxel].y;
        dipole.zpos = g_voxelListPtr[voxel].z;
        
        // Get distance of voxel from center of sphere for min radius check
        radial.x = dipole.xpos - g_sphereX;
        radial.y = dipole.ypos - g_sphereY;
        radial.z = dipole.zpos - g_sphereZ;
        voxelRadius = vectorLength( radial );
        
        dipole.xori = g_normalListPtr[voxel].x;
        dipole.yori = g_normalListPtr[voxel].y;
        dipole.zori = g_normalListPtr[voxel].z;
        
        // removed flagging for zero normal
        //        double len = dipole.xori + dipole.yori + dipole.zori;
        //        if ( voxelRadius < minRadius || len == 0.0 )
        
        if ( voxelRadius < minRadius )
        {
            for(int j=0; j<NDIR; j++)
            {
                for(int k=0; k<g_numSensors; k++)
                {
                    wts[j][k] = 0.0;
                }
            }
        }
        else
        {
            if (g_numWeightVectors == 1 && !g_optimizeOrientation)
            {
                // if computing fixed orientation weights, computation is simple...

                dipole.moment = 1.0e9;   // need to set this value!
                
                // Compute the forward solution for the optimal or fixed dipole orientation
                if ( !computeForwardSolution( g_dsParams, dipole, h[0], false, g_gradientOrder, computeMagnetic, useDewar) )
                {
                    printf("computeForwardSolution() returned error\n");
                    abort();
                }

                // compute one-dimensional (scalar) weights
                // get BC'
                for (int j=0; j<g_numSensors; j++)
                {
                    w[j] = 0.0;
                    for (int k=0; k<g_numSensors; k++)
                        w[j] += h[0][k] * g_iCovArray[j][k];
                }
                //  get denom =  BC'B
                double scalar_denom = 0.0;
                for (int k=0; k<g_numSensors; k++)
                    scalar_denom += w[k] * h[0][k];
                
                // get weights = BC' / BC'B
                for(int k=0; k<g_numSensors; k++)
                    wts[0][k] = w[k]/ scalar_denom;
                            
            }
            else
            {
                ///////////////////////////////////////////////////////
                //  D. Cheyne, March, 2010
                //  compute vector beamformer weights for m sensors
                //  using standard LCMV beamformer equation...
                //  h = 2 x m forward matrix for 2 orthogonal dipoles in sphere (psi = 0 and 90 degrees)
                //  iCov = inverse of m x m covariance matrix (defined as static global!)
                //  wts = h' iCov  * inv[h' iCov h]
                //////////////////////////////////////////////////////
    
                // get a unit vector that defines the radial direction for this voxel
                // using dipole position vector.
                
                radial.x = dipole.xpos - g_sphereX;
                radial.y = dipole.ypos - g_sphereY;
                radial.z = dipole.zpos - g_sphereZ;
                radial = unitVector(radial);
                                
                // define dipole orientation as zero local angle
                // note that this is the angle that optimal orientation
                // is relative to.  If these angles are rotated from zero, must also
                // rotate the angle returned by the eigendecomposition below...
                //
                orient = psi2cart(radial,0.0);
                orient = unitVector(orient);
                dipole.xori = orient.x;
                dipole.yori = orient.y;
                dipole.zori = orient.z;
                dipole.moment = 1.0e9;
                
                if ( !computeForwardSolution( g_dsParams, dipole, h[0], false, g_gradientOrder, computeMagnetic, useDewar ) )
                {
                    printf("computeForwardSolution() returned error\n");
                    abort();
                }
                
                // now get forward solution for orthogonal source
                orient = psi2cart(radial, 90.0);
                orient = unitVector(orient);
                dipole.xori = orient.x;
                dipole.yori = orient.y;
                dipole.zori = orient.z;
                dipole.moment = 1.0e9;
                
                if ( !computeForwardSolution( g_dsParams, dipole, h[1], false, g_gradientOrder, computeMagnetic, useDewar ) )
                {
                    printf("computeForwardSolution() returned error\n");
                    abort();
                }
                                
                // compute non-noise normalized vector weights
                // W = h' iCov * inv[h' iCov h]

                //   numerator = h' * iCov
                for (int i=0; i<NDIR; i++)
                {
                    for (int j=0; j<g_numSensors; j++)
                    {
                        num[i][j] = 0.0;
                        for (int k=0; k<g_numSensors; k++)
                            num[i][j] += h[i][k] * g_iCovArray[j][k];
                    }
                }
                //  denom =  inv[h' iCov h] = inv [num * h ]
                for (int i=0; i<NDIR; i++)
                {
                    for (int j=0; j<NDIR; j++)
                    {
                        denom[i][j] = 0.0;
                        for (int k=0; k<g_numSensors; k++)
                            denom[i][j] += h[i][k] * num[j][k];
                    }
                }
                
                invertMatrix2D(denom);

                for (int i=0; i<NDIR; i++)
                {
                    for (int j=0; j<g_numSensors; j++)
                    {
                        wts[i][j] = (num[0][j] * denom[0][i] ) + (num[1][j] * denom[1][i]);
                    }
                }
                
                // if computing vector weights we are done...
                
                if (g_optimizeOrientation)
                {
                    // get the optimal dipole orientation using eigen-decomposition
                    // and recompute weights for that direction only...
                    // get 2 x 2 power matrix P = W'CW
                    // ** note we now use the passed covariance array that can be different iCovArray
                    
                    // W'C
                    //
                    for (int i=0; i<NDIR; i++)
                    {
                        for (int j=0; j<g_numSensors; j++)
                        {
                            num[i][j] = 0.0;
                            for (int k=0; k<g_numSensors; k++)
                                num[i][j] += wts[i][k] * g_CovArray[j][k];
                        }
                    }
                    // (W'C) x W
                    for (int i=0; i<NDIR; i++)
                    {
                        for (int j=0; j<NDIR; j++)
                        {
                            denom[i][j] = 0.0;
                            for (int k=0; k<g_numSensors; k++)
                                denom[i][j] += wts[i][k] * num[j][k];
                        }
                    }
                    
                    // normalize W'CW to unit length - Borgiotti-Kaplan beamformer
                    // not clear it makes a difference with or without normalization
                    
                    // get inverse of W'W
                    for (int i=0; i<NDIR; i++)
                    {
                        for (int j=0; j<NDIR; j++)
                        {
                            noise2D[i][j] = 0.0;
                            for (int k=0; k<g_numSensors; k++)
                                noise2D[i][j] += wts[j][k] * wts[i][k];
                        }
                    }
                    invertMatrix2D(noise2D);
                    
                    for (int i=0; i<NDIR; i++)
                    {
                        for (int j=0; j<NDIR; j++)
                        {
                            power2D[i][j] = 0.0;
                            for (int k=0; k<2; k++)
                                power2D[i][j] += denom[k][j] * noise2D[i][k];
                        }
                    }

//                    // w/o weight-vector normalization
//                    for (int i=0; i<NDIR; i++)
//                    {
//                        for (int j=0; j<NDIR; j++)
//                        {
//                            power2D[i][j] = denom[i][j];
//                        }
//                    }
                    
                    // get dominant orientation from power
                    // compute eigenvalues and eigenvectors
                    // Note this assumes a symmetric NDIRxNDIR matrix A = [a b; b c]
                    
                    double lambda1;
                    double lambda2;
                    double x1;
                    double x2;
                    double y1;
                    double y2;
                    
                    // get eigenvalues of NDIR x NDIR matrix
                    double a = power2D[0][0];
                    double b = power2D[0][1];    // asssumes always mat2D[0][1] = mat2D[1][0] !
                    double c = power2D[1][1];
                    
                    double disc = sqrt((a-c)*(a-c)+4*b*b)/2.0;
                    lambda1 = (a+c)/2.0 + disc;
                    lambda2 = (a+c)/2.0 - disc;
                    // compute weights for best local angle
                    // this is given by eigenvector[x1,x2] for largest eigenvalue.
                    // this eigenvector is component of dipole 1 (always = local angle of 0 degrees)
                    // thus the local angle is the azimuth angle of this vector w.r.t dipole 1
                    
                    // get eigenVector corresponding to max eigenValue
                    x1 = -b;
                    if ( lambda1 > lambda2)
                        x2 = a-lambda1;
                    else
                        x2 = a-lambda2;
                    double mag = sqrt(x1*x1 + x2*x2);
                    x1 /= mag;
                    x2 /= mag;
                    
                    vectorCart cvec;
                    vectorSph  svec;
                    cvec.x = x1;
                    cvec.y = x2;
                    cvec.z = 0.0;
                    
                    svec = cartesian2spherical(cvec);
                    double t = svec.azimuth;
                    
                    double angle = Rad2Deg(t);
                    
                    // this is optimal angle RELATIVE to direction of the dipoles
                    // keep angle in range from 0 to 180 degrees
                    if (angle > 180 )
                        angle -= 180.0;
                                        
                    orient = psi2cart(radial, angle);
                    orient = unitVector(orient);
                    
                    // this is optimal orientation in x, y z coordinates
                    
                    dipole.xori = orient.x;
                    dipole.yori = orient.y;
                    dipole.zori = orient.z;
                    dipole.moment = 1.0e9;
    
                    // now compute the forward solution
                    // and weights for the optimal dipole orientation
                    if ( !computeForwardSolution( g_dsParams, dipole, h[0], false, g_gradientOrder, computeMagnetic, useDewar) )
                    {
                        printf("computeForwardSolution() returned error\n");
                        abort();
                    }
                    
                    for (int j=0; j<g_numSensors; j++)
                    {
                        w[j] = 0.0;
                        for (int k=0; k<g_numSensors; k++)
                            w[j] += h[0][k] * g_iCovArray[j][k];
                    }
                    //  get denom =  BC'B
                    double scalar_denom = 0.0;
                    for (int k=0; k<g_numSensors; k++)
                        scalar_denom += w[k] * h[0][k];
                    
                    // get weights = BC' / BC'B
                    for(int k=0; k<g_numSensors; k++)
                        wts[0][k] = w[k]/ scalar_denom;
                
                    // return the optimized dipole orientation in normalListPtr
                    g_normalListPtr[voxel].x = dipole.xori;
                    g_normalListPtr[voxel].y = dipole.yori;
                    g_normalListPtr[voxel].z = dipole.zori;
                    
                }
            }
            
        } // next voxel for this thread
        
        // Lock the mutex and update shared variables
        
        pthread_mutex_lock(&wtsArrayMutex);
        
        // Increment total voxels computed so far
        
        
         //Save weights for this voxel in big static global array
         //to pass back to calling function

        for (int i=0; i<g_numWeightVectors; i++)
            for (int k=0;k<g_numSensors;k++)
                g_wtsArrayPtr[i][voxel][k] = wts[i][k];

        // ** new save forward solutions in separate array
        for (int i=0; i<g_numWeightVectors; i++)
            for (int k=0;k<g_numSensors;k++)
                g_fwdArrayPtr[i][voxel][k] = h[i][k];
        
        pthread_mutex_unlock(&wtsArrayMutex);
        
        g_totVoxels++;
        if ( showPercentDone )
            printPercentDone( g_totVoxels, g_numVoxels);
        
        
    }    // next voxel;
    
    
    // *****
    // Free all memory
    
    for (int i = 0; i < NDIR; i++)
    {
        free(wts[i]);
        free(num[i]);
        free(h[i]);
    }
    free(wts);
    free(num);
    free(h);
    free(w);
    pthread_exit((void *) 0);
    
    return 0;
}

// New version of computeBeamformerWeights that returns the array of forward solutions as well as weights for each voxel
//
bool computeBeamformerWeightsNew(
                        char *dsName,
                        ds_params & dsParams,
                        double ***forward_array,
                        double ***weight_array,
                        int numWeightVectors,
                        double **covArray,
                        double **icovArray,
                        vectorCart *voxelList,
                        vectorCart *normalList,
                        int numVoxels,
                        bool optimizeOrientation)
{
    
    if (weight_array == NULL)
    {
        printf("null pointer for weight_array in computeBeamformerWeights...\n");
        return (false);
    }

    // initialize static globals for variable passing during threading
    // these are defined in sourceUtils.h

    if ( !readMEGResFile( dsName, g_dsParams) )
    {
      printf("Could not open MEG resource in dataset [%s]\n", dsName);
      return(false);
    }
    g_dsNamePtr = dsName;
    g_dsParams = dsParams;

    g_voxelListPtr = voxelList;
    g_normalListPtr = normalList;

    g_numSensors = g_dsParams.numSensors;
    g_numVoxels = numVoxels;
    g_numWeightVectors = numWeightVectors;
    g_fwdArrayPtr = forward_array;
    g_wtsArrayPtr = weight_array;
    
    g_optimizeOrientation = optimizeOrientation;
    g_gradientOrder = g_dsParams.gradientOrder;

    g_CovArray = covArray;
    g_iCovArray = icovArray;
    
    g_sphereX = 0.0;
    g_sphereY = 0.0;
    g_sphereZ = 0.0;
    int sensorCount = 0;
    for (int i=0; i < g_dsParams.numChannels; i++)
    {
        // get mean sphere -- include balancing refs
        if ( g_dsParams.channel[i].isSensor || g_dsParams.channel[i].isBalancingRef )
        {
            g_sphereX += g_dsParams.channel[i].sphereX;
            g_sphereY += g_dsParams.channel[i].sphereY;
            g_sphereZ += g_dsParams.channel[i].sphereZ;
            sensorCount++;
        }
    }
    g_sphereX /= (double)sensorCount;
    g_sphereY /= (double)sensorCount;
    g_sphereZ /= (double)sensorCount;
    printf("Using mean sphere origin: %g, %g, %g\n", g_sphereX, g_sphereY, g_sphereZ);
    

    // threading starts here
    // **********************

    // threading code from M. Quraan
    
    // int *voxelID[NUM_WTS_THREADS];
    
    // Set thread attributes to be joinable
    
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
    
    // Initialize the mutex
    
    pthread_mutex_init(&wtsArrayMutex, NULL);
            

    // Determine boundaries for each thread
    
    int voxelsPerThread;
    if( numVoxels < NUM_WTS_THREADS )
    {
        voxelsPerThread = 1;
    }
    else
    {
        voxelsPerThread = numVoxels/NUM_WTS_THREADS;
    }
    int voxelStart = 0;
    int voxelEnd = voxelsPerThread;
    if( voxelEnd > numVoxels) voxelEnd = numVoxels;
    
    thread_wts_t wtsThreadData[NUM_WTS_THREADS];
    
    if (numWeightVectors == 1)
        printf("computing scalar weights...\n");
    else
        printf("computing vector weights...\n");

    if (g_optimizeOrientation)
        printf("optimizing source orientation using eigendecomposition ...\n");
               
    // Calculate the weights
    
    int numActualThreads = 0;
    g_totVoxels = 0;
    
    for (int iThread=0; iThread<NUM_WTS_THREADS; iThread++)
    {
        numActualThreads++;
        wtsThreadData[iThread].threadID = iThread;
        wtsThreadData[iThread].voxelStart = voxelStart;
        wtsThreadData[iThread].voxelEnd = voxelEnd;
        
        //printf("iThread = %d, voxelStart = %d, voxelEnd = %d\n", iThread, voxelStart, voxelEnd-1);
        
        int rc = pthread_create(&wtsThreads[iThread], &attr, wtsThreadNew, (void *) &wtsThreadData[iThread]);
        if (rc)
        {
            printf("ERROR; return code from pthread_create() is %d\n", rc);
            return( false);
        }
        
        voxelStart += voxelsPerThread;
        if( voxelStart >= numVoxels )
            break;
        voxelEnd += voxelsPerThread;
        if( voxelEnd > numVoxels )
            voxelEnd = numVoxels;
        // if( (numVoxels-voxelEnd) < voxelsPerThread ) voxelEnd = numVoxels;
        if( iThread==(NUM_WTS_THREADS-2) )
            voxelEnd = numVoxels;
    }
    
    // Join all threads
    
    for (int iThread=0; iThread<numActualThreads; iThread++)
    {
        int status;
        int rc = pthread_join(wtsThreads[iThread], (void **)&status);
        if (rc)
        {
            printf("ERROR return code from pthread_join() is %d\n", rc);
            return ( false);
        }
        //printf("Completed join with thread %d status= %d\n",iThread, status);
        
    }
        
    // Free threading resources

//    pthread_mutex_unlock(&wtsArrayMutex);
    pthread_attr_destroy(&attr);
    pthread_mutex_destroy(&wtsArrayMutex);
    
    printf("\n...done\n");
    
    return(true);
}


bool computeCovarianceMatrices(double **covArray, double **icovArray, int numSensors, char *dsName, filter_params & fparams, 
			   double wStart, double wEnd, double aStart, double aEnd, bool useAngleWindow, double regularization)
{
	double		*covArrayDiag;
	
	FILE		*fp;
	char		covFileName[256];
	char		dsBaseName[64];
	
	double  lowPass = fparams.hc;
	double  hiPass = fparams.lc;
    bool    applyRegularization = false;
	
	// NEW ** check for saved covariance in .ds folder
	// these are specific to BW and data window start and end times only!
	removeDotExtension(dsName, covFileName);		
	removeFilePath(covFileName, dsBaseName);		
	
	if (fparams.bidirectional)
		sprintf(covFileName, "%s%s%s_w_%g_%g_%g_%gHz.cov", dsName,FILE_SEPARATOR, dsBaseName, wStart, wEnd, hiPass, lowPass);
	else
		sprintf(covFileName, "%s%s%s_w_%g_%g_%g_%gHz_NR.cov", dsName,FILE_SEPARATOR, dsBaseName, wStart, wEnd, hiPass, lowPass);
		
	if ( (fp = fopen(covFileName,"r")) != NULL)
	{
		printf("reading existing covariance data from  %s...\n", covFileName);
		for (int k=0; k<numSensors; k++)
			for (int j=0; j<numSensors; j++)
				nBytesRead = fscanf(fp, "%lf", &covArray[k][j]);
		fclose(fp);
	}
	else
	{		
		// calculate covariance for specified window
		printf("computing covariance for weight calculation...\n");		
		if ( !getSensorCovariance(dsName, wStart, wEnd, covArray, fparams) )
		{
			printf("Error encountered creating covariance... exiting\n");
			return(false);
		}
		
		printf("Saving covariance data in file %s\n", covFileName);

		//printf("The covariance matrix element is %g\n",covArray[0][0]);

		fp = fopen(covFileName,"w");
		if (fp != NULL)
		{
			for (int k=0; k<numSensors; k++)
				for (int j=0; j<numSensors; j++)
					fprintf(fp, "%g\n", covArray[k][j]);
		}
		fclose(fp);
	}
	
	printf("inverting covariance matrix...\n");
    
    
    if (regularization != 0.0)
    {
		covArrayDiag = (double *)malloc( sizeof(double) * numSensors );
		if (covArrayDiag == NULL)
		{
			printf("memory allocation failed for covariance array diagonal elements\n");
			return(false);
		}
		printf("Regularizing covariance matrix by %g ...Tesla^2\n", regularization);
		// add constant to diagonal
        for (int k=0; k<numSensors; k++)
		{
			covArrayDiag[k] = covArray[k][k];   // save original values
            covArray[k][k] += regularization;
		}
    }

	if ( !invertMatrix(covArray, icovArray, numSensors) )
    {
		printf("Error encountered inverting covariance matrix... exiting\n");
		return(false);
    }
	
	// restore non-regularized cov array
	if ( regularization != 0.0 )
    {
		for (int k=0; k<numSensors; k++)
			covArray[k][k] = covArrayDiag[k];
				
		free(covArrayDiag);
    }
	
	// if using angle we we recompute the covArray with the aw window boundaries
	// but also return the inverse covariance for the cw window boundaries.
	
	if (useAngleWindow)
	{
		sprintf(covFileName, "%s%s%s_w_%g_%g_%g_%gHz.cov", dsName,FILE_SEPARATOR, dsBaseName, aStart, aEnd, hiPass, lowPass);	
		if ( (fp = fopen(covFileName,"r")) != NULL)
		{
			printf("Reading covariance data for angle optimization from  %s...\n", covFileName);
			for (int k=0; k<numSensors; k++)
				for (int j=0; j<numSensors; j++)
					nBytesRead = fscanf(fp, "%lf", &covArray[k][j]);
			fclose(fp);
		}
		else
		{
			// calculate covariance for specified window
			printf("computing covariance for angle optimization calculation...\n");		
			if ( !getSensorCovariance(dsName, aStart, aEnd, covArray, fparams) )
			{
				printf("Error encountered creating covariance... exiting\n");
				return(false);
			}
			printf("Saving covariance data in file %s\n", covFileName);
			fp = fopen(covFileName,"w");
			if (fp != NULL)
			{
				for (int k=0; k<numSensors; k++)
					for (int j=0; j<numSensors; j++)
						fprintf(fp, "%g\n", covArray[k][j]);
			}
			fclose(fp);		
		}
	}
	
	return (true);
}

bool computeVS(double **vsData, char *dsName, ds_params & dsParams, filter_params & fparams, bf_params & bparams, 
	double **covArray, double **icovArray, double x, double y, double z, double *xo, double *yo, double *zo, bool computeSingleTrials)
{

	double      *w;
	vectorCart	radial;
	vectorCart	orient;
	int			numWeightVectors;
	bool		optimizeOrientation;
	bool		baselineData = false;
	double		bStart = 0.0;
	double		bEnd = 0.0;
	
	double		lowPass = fparams.hc;
	double		hiPass = fparams.lc;
	vectorCart	*voxelList;
	vectorCart	*normalList;	

	if (bparams.type == BF_TYPE_RMS)
		numWeightVectors = 2;
	else
		numWeightVectors = 1;
	
	if (bparams.type == BF_TYPE_OPTIMIZED)
		optimizeOrientation = true;
	else
		optimizeOrientation = false;

	if (bparams.baselined)
	{
		baselineData = true;
		bStart = bparams.baselineWindowStart;
		bEnd = bparams.baselineWindowEnd;
	}
	
	///////////////////////////////////////////////////////////////
	// since we are just computing weights for one voxel 
	// just setup dummy voxel and normal list arrays for one voxel
	///////////////////////////////////////////////////////////////
	
	int numVoxels = 1;
	
	voxelList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
	if ( voxelList == NULL)
	{
		printf("Could not allocate memory for voxel lists\n");
		return(false);
	}
	
	normalList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
	if ( normalList == NULL)
	{
		printf("Could not allocate memory for voxel lists\n");
		return(false);
	}
	
	voxelList[0].x = x;
	voxelList[0].y = y;
	voxelList[0].z = z;
	
	normalList[0].x = *xo;
	normalList[0].y = *yo;
	normalList[0].z = *zo;	
	
	if (bparams.type == BF_TYPE_FIXED)
		printf("Using fixed source orientation: <%.4f %.4f %.4f>\n", *xo, *yo, *zo);
	
	////////////////////////////////////////////////////////////
	// allocate memory for weights array
	////////////////////////////////////////////////////////////
	
	bw_weight_array = (double ***)malloc( sizeof(double **) * numWeightVectors );
	if (bw_weight_array == NULL)
	{
		printf("memory allocation failed for weights array");
		return(false);
	}
	for (int i=0; i <numWeightVectors; i++)
	{
		bw_weight_array[i] = (double **)malloc( sizeof(double *) * numVoxels );
		if ( bw_weight_array[i] == NULL)
		{
			printf( "memory allocation failed for weights array" );
			return(false);
		}
		for (int j=0; j <numVoxels; j++)
		{
			bw_weight_array[i][j] = (double *)malloc( sizeof(double) * dsParams.numSensors );
			if ( bw_weight_array[i][j] == NULL)
			{
				printf( "memory allocation failed for weights array" );
				return(false);
			}
		}  		
	}
    
    ////////////////////////////////////////////////////////////
    // allocate memory for forward array
    ////////////////////////////////////////////////////////////
    
    bw_forward_array = (double ***)malloc( sizeof(double **) * numWeightVectors );
    if (bw_forward_array == NULL)
    {
        printf("memory allocation failed for forward array");
        return(false);
    }
    for (int i=0; i <numWeightVectors; i++)
    {
        bw_forward_array[i] = (double **)malloc( sizeof(double *) * numVoxels );
        if ( bw_forward_array[i] == NULL)
        {
            printf( "memory allocation failed for forward array" );
            return(false);
        }
        for (int j=0; j <numVoxels; j++)
        {
            bw_forward_array[i][j] = (double *)malloc( sizeof(double) * dsParams.numSensors );
            if ( bw_forward_array[i][j] == NULL)
            {
                printf( "memory allocation failed for forward array" );
                return(false);
            }
        }
    }
	
	/////////////////////////////
	// compute beamformer weights
	/////////////////////////////
	if ( !computeBeamformerWeightsNew(dsName, dsParams, bw_forward_array, bw_weight_array, numWeightVectors, covArray,
					icovArray, voxelList, normalList, numVoxels, optimizeOrientation) )
	{
		printf("computeBeamformerWeights returned error ...\n");
		return(false);
	}
	
	// return optimized normal vector in the normalList
	
	if (bparams.type == BF_TYPE_OPTIMIZED)
	{
		*xo = normalList[0].x;
		*yo = normalList[0].y;
		*zo = normalList[0].z;
		printf("Optimal source orientation is: <%.4f %.4f %.4f>\n", *xo, *yo, *zo);
	}
	
	// Normalize weights
	//
	if (bparams.normalized)
	{
		double BW = lowPass - hiPass;
		double noise = bparams.noiseRMS * bparams.noiseRMS * BW;	// convert noise to power in the bandwidth used
		
		printf("Normalizing weights using mean sensor noise = %g fT per root Hz, (BW = %g Hz)...\n", bparams.noiseRMS * 1e15, BW );
		for (int voxel=0; voxel<numVoxels; voxel++)
		{
			for (int i=0; i<numWeightVectors; i++)
			{			
				double projNoise = 0.0;
				for (int j=0; j<dsParams.numSensors; j++)
					projNoise += bw_weight_array[i][voxel][j] * bw_weight_array[i][voxel][j] * noise;
				// normalize weights
				if ( projNoise != 0.0 )
				{
					for (int j=0; j<dsParams.numSensors; j++)
					{
						bw_weight_array[i][voxel][j] /= sqrt(projNoise);
					}
				}
			}
		}
	}
	
    //printf("Normalizing has finished");

	double unitScale;
	if ( bparams.normalized )
		unitScale = 1.0;
	else
		unitScale = 1e9;
	
	// since we don't need to transpose on the fly we only need to hold one trial (or average) in memory
	// 
	bw_trialData = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (bw_trialData == NULL)
	{
		printf("memory allocation failed for trial array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		bw_trialData[i] = (double *)malloc( sizeof(double) * dsParams.numSamples);
		if ( bw_trialData[i] == NULL)
		{
			printf( "memory allocation failed for trial array" );
			return(false);
		}
	}
	
	if (computeSingleTrials)
	{
		printf ("\nComputing virtual sensor data for %d trials...\n", dsParams.numTrials);
		for (int trial=0; trial<dsParams.numTrials; trial++)
		{
			if ( !getSensorData( dsName, dsParams, bw_trialData, trial, fparams) )
			{
				printf("Error returned from getSensorData...\n");
				exit(0);
			}
			for (int i=0; i<dsParams.numSamples; i++)
			{			  
				double projMom = 0.0;
				for (int j=0; j<dsParams.numSensors; j++)
					projMom += bw_trialData[j][i] * bw_weight_array[0][0][j];
			
				if ( bparams.type == BF_TYPE_RMS )
				{
					double orthogMom = 0.0;
					for (int j=0; j<dsParams.numSensors; j++)
						orthogMom += bw_trialData[j][i] * bw_weight_array[1][0][j];
					projMom = sqrt( (projMom * projMom) + (orthogMom * orthogMom) );
				}
				vsData[trial][i] = projMom * unitScale;
			}
			
			printf(".");
			fflush(stdout);
		}
	}
	else
	{
		printf ("\nComputing virtual sensor data for average...\n");
		
		FILE		*fp;
		char		aveFileName[256];
		char		dsBaseName[64];
		
		removeDotExtension(dsName, aveFileName);		
		removeFilePath(aveFileName, dsBaseName);		

		// save separate average file for non-reversing filter
		if (fparams.bidirectional)
			sprintf(aveFileName, "%s%s%s_%g_%gHz.ave", dsName,FILE_SEPARATOR, dsBaseName, hiPass, lowPass);
		else
			sprintf(aveFileName, "%s%s%s_%g_%gHz_NR.ave", dsName,FILE_SEPARATOR, dsBaseName, hiPass, lowPass);
		
		if ( (fp = fopen(aveFileName,"r")) != NULL)
		{
			printf("Reading existing average file %s...\n", aveFileName);
			for (int k=0; k<dsParams.numSensors; k++)
				for (int j=0; j<dsParams.numSamples; j++)
					nBytesRead = fscanf(fp, "%lf", &bw_trialData[k][j]);
			fclose(fp);
		}
		else
		{
			if ( !getSensorDataAverage( dsName, dsParams, bw_trialData, fparams) )
			{
				printf("Error returned from getSensorDataAverage...\n");
				exit(0);
			}
			
			printf("Saving filtered data average in file %s\n", aveFileName);
			fp = fopen(aveFileName,"w");
			if (fp != NULL)
			{
					for (int k=0; k<dsParams.numSensors; k++)
						for (int j=0; j<dsParams.numSamples; j++)
							fprintf(fp, "%g\n", bw_trialData[k][j]);
			}
			fclose(fp);
		}
		
		if ( baselineData )
		{
			int b1 = (int)( (bStart * dsParams.sampleRate) + 0.5) + dsParams.numPreTrig;
			int b2 = (int)( (bEnd * dsParams.sampleRate) + 0.5) + dsParams.numPreTrig;
			int bpoints = b2-b1+1;
			
			printf("removing baseline from averaged data %g s to %g s (sample %d to %d) \n", bStart, bEnd, b1, b2);
			if (b2 < b1)
			{
				printf("invalid baseline period... check input parameters\n");
				return(false);
			}
			
			for (int j=0; j < dsParams.numSensors; j++)
			{
				double mean = 0.0;
				for (int k=b1; k<=b2; k++)
					mean += bw_trialData[j][k];
				mean /= (double)bpoints;
				for (int k=0; k< dsParams.numSamples; k++)
					bw_trialData[j][k] -= mean;
			}
		}

		// compute projected moment at each time sample for the average
		for (int i=0; i<dsParams.numSamples; i++)
		{			  
			double projMom = 0.0;
			for (int j=0; j<dsParams.numSensors; j++)
				projMom += bw_trialData[j][i] * bw_weight_array[0][0][j];
			if (bparams.type == BF_TYPE_RMS)
			{
				double orthogMom = 0.0;
				for (int j=0; j<dsParams.numSensors; j++)
					orthogMom += bw_trialData[j][i] * bw_weight_array[1][0][j];
				projMom = sqrt( (projMom * projMom) + (orthogMom * orthogMom) );
			}
			vsData[0][i] = projMom * unitScale;
		}
	}

	// free memory for data array...
	for (int i = 0; i < dsParams.numSensors; i++)
		free(bw_trialData[i]);
	free(bw_trialData);
		
	// free memory for weight arrays...
	for (int i=0; i <numWeightVectors; i++)
	{
		for (int j=0; j <numVoxels; j++)
			free(bw_weight_array[i][j]);  
		free(bw_weight_array[i]);
	}
	free(bw_weight_array);

    // free memory for forward array...
    for (int i=0; i <numWeightVectors; i++)
    {
        for (int j=0; j <numVoxels; j++)
            free(bw_forward_array[i][j]);
        free(bw_forward_array[i]);
    }
    free(bw_forward_array);
        
    free(voxelList);
	free(normalList);
	
	
	return (true);
}

// modified Oct 9 / 2012
// changed from passing a fixed latency range and step to passing a list of latencies for more flexibility

bool computeEventRelated(double **imageData, char *dsName, ds_params & dsParams, filter_params & fparams, bf_params & bparams, double **covArray, double **icovArray,
			int numVoxels, vectorCart *voxelList, vectorCart *normalList, int numLatencies, double *latencyList, bool computePlusMinus, bool nonRectified )
{
	
	double      *w;
	vectorCart	radial;
	vectorCart	orient;
	int			numWeightVectors;
	bool		optimizeOrientation;
	bool		baselineData = false;
	double		bStart = 0.0;
	double		bEnd = 0.0;
	
	double		lowPass = fparams.hc;
	double		hiPass = fparams.lc;
	bool		computeRMS = false;
	

	if (bparams.type == BF_TYPE_RMS)
		numWeightVectors = 2;
	else
		numWeightVectors = 1;
	
	if (bparams.type == BF_TYPE_OPTIMIZED)
		optimizeOrientation = true;
	else
		optimizeOrientation = false;
	
	if (bparams.baselined)
	{
		baselineData = true;
		bStart = bparams.baselineWindowStart;
		bEnd = bparams.baselineWindowEnd;
	}
	
    printf("computeEventRelated version %.1f...\n", BWLIB_VERSION);
	if (bparams.type == BF_TYPE_FIXED)
		printf("Using fixed source orientations...\n");
	
	////////////////////////////////////////////////////////////
	// allocate memory for weights array
	////////////////////////////////////////////////////////////
	

	bw_weight_array = (double ***)malloc( sizeof(double **) * numWeightVectors );
	if (bw_weight_array == NULL)
	{
		printf("memory allocation failed for weights array");
		return(false);
	}
	for (int i=0; i <numWeightVectors; i++)
	{
		bw_weight_array[i] = (double **)malloc( sizeof(double *) * numVoxels );
		if ( bw_weight_array[i] == NULL)
		{
			printf( "memory allocation failed for weights array" );
			return(false);
		}
		for (int j=0; j <numVoxels; j++)
		{
			bw_weight_array[i][j] = (double *)malloc( sizeof(double) * dsParams.numSensors );
			if ( bw_weight_array[i][j] == NULL)
			{
				printf( "memory allocation failed for weights array" );
				return(false);
			}
		}  		
	}  
		
    ////////////////////////////////////////////////////////////
    // allocate memory for forward array
    ////////////////////////////////////////////////////////////
    
    bw_forward_array = (double ***)malloc( sizeof(double **) * numWeightVectors );
    if (bw_forward_array == NULL)
    {
        printf("memory allocation failed for forward array");
        return(false);
    }
    for (int i=0; i <numWeightVectors; i++)
    {
        bw_forward_array[i] = (double **)malloc( sizeof(double *) * numVoxels );
        if ( bw_forward_array[i] == NULL)
        {
            printf( "memory allocation failed for forward array" );
            return(false);
        }
        for (int j=0; j <numVoxels; j++)
        {
            bw_forward_array[i][j] = (double *)malloc( sizeof(double) * dsParams.numSensors );
            if ( bw_forward_array[i][j] == NULL)
            {
                printf( "memory allocation failed for forward array" );
                return(false);
            }
        }
    }
    
	/////////////////////////////
	// compute beamformer weights
	/////////////////////////////

	if ( !computeBeamformerWeightsNew(dsName, dsParams, bw_forward_array, bw_weight_array, numWeightVectors, covArray,
								   icovArray, voxelList, normalList, numVoxels, optimizeOrientation) ) 
	{
		printf("computeBeamformerWeights returned error ...\n");
		return(false);
	}
	
	//  Normalize weights
	
	if (bparams.normalized)
	{
		double BW = lowPass - hiPass;
		double noise = bparams.noiseRMS * bparams.noiseRMS * BW;	// convert noise to power in the bandwidth used
		
		printf("Normalizing weights using mean sensor noise = %g fT per root Hz, (BW = %g Hz)...\n", bparams.noiseRMS * 1e15, BW );
		for (int voxel=0; voxel<numVoxels; voxel++)
		{
			for (int i=0; i<numWeightVectors; i++)
			{			
				double projNoise = 0.0;
				for (int j=0; j<dsParams.numSensors; j++)
					projNoise += bw_weight_array[i][voxel][j] * bw_weight_array[i][voxel][j] * noise;
				// normalize weights
				if ( projNoise != 0.0 )
				{
					for (int j=0; j<dsParams.numSensors; j++)
					{
						bw_weight_array[i][voxel][j] /= sqrt(projNoise);
					}
				}
			}
		}	
	}
		
	// since we don't need to transpose on the fly we only need to hold one trial (or average) in memory
	// 
	bw_trialData = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (bw_trialData == NULL)
	{
		printf("memory allocation failed for trial array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		bw_trialData[i] = (double *)malloc( sizeof(double) * dsParams.numSamples);
		if ( bw_trialData[i] == NULL)
		{
			printf( "memory allocation failed for trial array" );
			return(false);
		}
	}

	FILE		*fp;
	char		aveFileName[256];
	char		dsBaseName[64];
	
//	removeDotExtension(dsName, aveFileName);		
//	removeFilePath(aveFileName, dsBaseName);		
//	sprintf(aveFileName, "%s%s%s_%g_%gHz.ave", dsName,FILE_SEPARATOR, dsBaseName, hiPass, lowPass);

	if (computePlusMinus)
	{
		if ( !getSensorDataPlusMinusAverage( dsName, dsParams, bw_trialData, fparams) )
		{
			printf("Error returned from getSensorDataPlusMinusAverage...\n");
			exit(0);
		}	
	}
	else
	{
		FILE		*fp;
		char		aveFileName[4096];
		char		dsBaseName[256];
		
		removeDotExtension(dsName, aveFileName);		
		removeFilePath(aveFileName, dsBaseName);
		
		// save separate average file for non-reversing filter
		if (fparams.bidirectional)
			sprintf(aveFileName, "%s%s%s_%g_%gHz.ave", dsName,FILE_SEPARATOR, dsBaseName, hiPass, lowPass);
		else
			sprintf(aveFileName, "%s%s%s_%g_%gHz_NR.ave", dsName,FILE_SEPARATOR, dsBaseName, hiPass, lowPass);
		
		if ( (fp = fopen(aveFileName,"r")) != NULL)
		{
			printf("Reading existing average file %s...\n", aveFileName);
			for (int k=0; k<dsParams.numSensors; k++)
				for (int j=0; j<dsParams.numSamples; j++)
					nBytesRead = fscanf(fp, "%lf", &bw_trialData[k][j]);
			fclose(fp);
		}
		else
		{
			if ( !getSensorDataAverage( dsName, dsParams, bw_trialData, fparams) )
			{
				printf("error returned from getSensorDataAverage...\n");
				return(false);
			}
			printf("Saving filtered data average in file %s\n", aveFileName);
			fp = fopen(aveFileName,"w");
			if (fp != NULL)
			{
				for (int k=0; k<dsParams.numSensors; k++)
					for (int j=0; j<dsParams.numSamples; j++)
						fprintf(fp, "%g\n", bw_trialData[k][j]);
			}
			fclose(fp);
		}
	}
	
	if ( baselineData )
	{
		int b1 = (int)( (bStart * dsParams.sampleRate) + 0.5) + dsParams.numPreTrig;
		int b2 = (int)( (bEnd * dsParams.sampleRate) + 0.5) + dsParams.numPreTrig;
		int bpoints = b2-b1+1;
		
		printf("removing baseline from averaged data %g s to %g s (sample %d to %d) \n", bStart, bEnd, b1, b2);
		if (b2 < b1)
		{
			printf("invalid baseline period... check input parameters\n");
			return(false);
		}
				
		for (int j=0; j < dsParams.numSensors; j++)
		{
			double mean = 0.0;
			for (int k=b1; k<=b2; k++)
				mean += bw_trialData[j][k];
			mean /= (double)bpoints;
			for (int k=0; k< dsParams.numSamples; k++)
				bw_trialData[j][k] -= mean;
		}
	}
	
	////////////////////////////////////
	// compute images over all latencies 
	////////////////////////////////////
		
	printf("Creating event-related source images for %d time samples... \n", numLatencies);
	
	int sample;
	double latency;
	
	for (int i=0; i<numLatencies; i++)
	{
		latency = latencyList[i];
		
		sample = (int)( (latency * dsParams.sampleRate) + 0.5) + dsParams.numPreTrig;
		// printf("Computing image for time = %g (sample %d) \n", latency, sample);
		
		if ( sample < 0 || sample >= dsParams.numSamples )
		{
			printf("Invalid sample number -- check time range\n");
			return(false);
		}
		
		for (int voxel=0; voxel<numVoxels; voxel++)
		{
			imageData[i][voxel] = 0.0;
			double projMom = 0.0;
			
			// compute projected moment for primary direction
			for (int j=0; j<dsParams.numSensors; j++)
				projMom += bw_trialData[j][sample] * bw_weight_array[0][voxel][j];
			
			// optionally take rms of vector weight output this is same as
			// LCMV power calculation (P = W'CW) for data covariance of one sample duration
			//
			if (bparams.type == BF_TYPE_RMS)
			{
				double orthogMom = 0.0;
				for (int j=0; j<dsParams.numSensors; j++)
					orthogMom += bw_trialData[j][sample] * bw_weight_array[1][voxel][j];
				projMom = sqrt( (projMom * projMom) + (orthogMom * orthogMom) );
			}		
			
			// take absolute value for event-related
			if (nonRectified)
				imageData[i][voxel] = projMom;
			else
				imageData[i][voxel] = fabs(projMom);	
			
		} // next voxel
		
		printf(".");
		fflush(stdout);
		
	}
	printf("\n");
	
	// free memory for data array...
	for (int i = 0; i < dsParams.numSensors; i++)
		free(bw_trialData[i]);
	free(bw_trialData);
	
	// free memory for weight arrays...
	for (int i=0; i <numWeightVectors; i++)
	{
		for (int j=0; j <numVoxels; j++)
			free(bw_weight_array[i][j]);  
		free(bw_weight_array[i]);
	}
	free(bw_weight_array);
	
    // free memory for forward array...
    for (int i=0; i <numWeightVectors; i++)
    {
        for (int j=0; j <numVoxels; j++)
            free(bw_forward_array[i][j]);
        free(bw_forward_array[i]);
    }
    free(bw_forward_array);
    
	return (true);
}

// * compute CTF and PSF images for specified voxel in the passed voxelList.
// * returns images in vectors imageData[0][nvoxels] and imageData[1][nvoxels], respectively.
// * need to pass a voxel index i to compute the CTF and PSF images from the returned weights(W) and forward solution(B) arrays, where,
// CTF(i) = W(i) * B(1.nvoxels);  (cross-talk function map corresponding to row i of resolution matrix)
// PSF(i) = B(i) * W(1.novels);   (point-spread function map corresponding to column i of resolution matrix)

bool computeCrossTalk(double **imageData, char *dsName, ds_params & dsParams, bf_params & bparams, double **covArray, double **icovArray, int numVoxels,
                      vectorCart *voxelList, vectorCart *normalList, int targetVoxel)
{
    
    double          *w;
    vectorCart      radial;
    vectorCart      orient;
    int             numWeightVectors;
    bool            optimizeOrientation;


    
    if (bparams.type == BF_TYPE_RMS)
    {
        printf("Currently only computes CTF and PSF for scalar beamformers ...\n");
        return(false);
    }
    
    numWeightVectors = 1;
    
    if (bparams.type == BF_TYPE_OPTIMIZED)
        optimizeOrientation = true;
    else
        optimizeOrientation = false;
    
    printf("computeCrossTalk version %.1f...\n", BWLIB_VERSION);
    
    if (bparams.type == BF_TYPE_FIXED)
        printf("Using fixed source orientations...\n");
    
    ////////////////////////////////////////////////////////////
    // allocate memory for weights array
    ////////////////////////////////////////////////////////////
    printf("allocating memory..\n");
    bw_weight_array = (double ***)malloc( sizeof(double **) * numWeightVectors );
    if (bw_weight_array == NULL)
    {
        printf("memory allocation failed for weights array");
        return(false);
    }
    for (int i=0; i <numWeightVectors; i++)
    {
        bw_weight_array[i] = (double **)malloc( sizeof(double *) * numVoxels );
        if ( bw_weight_array[i] == NULL)
        {
            printf( "memory allocation failed for weights array" );
            return(false);
        }
        for (int j=0; j <numVoxels; j++)
        {
            bw_weight_array[i][j] = (double *)malloc( sizeof(double) * dsParams.numSensors );
            if ( bw_weight_array[i][j] == NULL)
            {
                printf( "memory allocation failed for weights array" );
                return(false);
            }
        }
    }
        
    ////////////////////////////////////////////////////////////
    // allocate memory for forward array
    ////////////////////////////////////////////////////////////
    
    bw_forward_array = (double ***)malloc( sizeof(double **) * numWeightVectors );
    if (bw_forward_array == NULL)
    {
        printf("memory allocation failed for forward array");
        return(false);
    }
    for (int i=0; i <numWeightVectors; i++)
    {
        bw_forward_array[i] = (double **)malloc( sizeof(double *) * numVoxels );
        if ( bw_forward_array[i] == NULL)
        {
            printf( "memory allocation failed for forward array" );
            return(false);
        }
        for (int j=0; j <numVoxels; j++)
        {
            bw_forward_array[i][j] = (double *)malloc( sizeof(double) * dsParams.numSensors );
            if ( bw_forward_array[i][j] == NULL)
            {
                printf( "memory allocation failed for forward array" );
                return(false);
            }
        }
    }
    
    /////////////////////////////
    // compute beamformer weights
    /////////////////////////////
    printf("computing beamformer weights...\n");

    if ( !computeBeamformerWeightsNew(dsName, dsParams, bw_forward_array, bw_weight_array, numWeightVectors, covArray,
                                   icovArray, voxelList, normalList, numVoxels, optimizeOrientation) )
    {
        printf("computeBeamformerWeights returned error ...\n");
        return(false);
    }
    
    //  Normalize weights
    
    if (bparams.normalized)
    {
        double noise = bparams.noiseRMS * bparams.noiseRMS;    // assume unity bandwidth
        
        printf("Normalizing weights ...\n");
        for (int voxel=0; voxel<numVoxels; voxel++)
        {
            for (int i=0; i<numWeightVectors; i++)
            {
                double projNoise = 0.0;
                for (int j=0; j<dsParams.numSensors; j++)
                    projNoise += bw_weight_array[i][voxel][j] * bw_weight_array[i][voxel][j] * noise;
                // normalize weights
                if ( projNoise != 0.0 )
                {
                    for (int j=0; j<dsParams.numSensors; j++)
                    {
                        bw_weight_array[i][voxel][j] /= sqrt(projNoise);
                    }
                }
            }
        }
    }
    

    // 1. create CTF image = weight vector for targetVoxel * all forward solution vectors

    double maxVal;
    printf("computing CTF image...\n");
    maxVal = 0.0;
    for (int voxel=0; voxel<numVoxels; voxel++)
    {
        imageData[0][voxel] = 0.0;
        //  this voxel value = weight vector for target voxel *  forward solution vector for this voxel
        for (int j=0; j<dsParams.numSensors; j++)
            imageData[0][voxel] += bw_weight_array[0][targetVoxel][j] * bw_forward_array[0][voxel][j];
        // since scalar beamformer has arbitrary polarity across voxels, have to take absolute value
        imageData[0][voxel] = fabs(imageData[0][voxel]);
        if (imageData[0][voxel] > maxVal)
            maxVal = imageData[0][voxel];
    } // next voxel
 
    // normalize image
    for (int voxel=0; voxel<numVoxels; voxel++)
        imageData[0][voxel] = (imageData[0][voxel] / maxVal) * 100;
    
    // 2. create PSF image = forward solution for targetVoxel * all weight vectors
    printf("computing PSF image...\n");
    maxVal = 0.0;
    for (int voxel=0; voxel<numVoxels; voxel++)
    {
        imageData[1][voxel] = 0.0;
        //  voxel value = forward solution for target voxel * weight vector for this voxel
        for (int j=0; j<dsParams.numSensors; j++)
            imageData[1][voxel] += bw_forward_array[0][targetVoxel][j] * bw_weight_array[0][voxel][j];
        // since scalar beamformer has arbitrary polarity across voxels, have to take absolute value
        imageData[1][voxel] = fabs(imageData[1][voxel]);
        if (imageData[1][voxel] > maxVal)
            maxVal = imageData[1][voxel];

    } // next voxel
    // normalize image to 100 %
    for (int voxel=0; voxel<numVoxels; voxel++)
        imageData[1][voxel] = (imageData[1][voxel] / maxVal) * 100;
    
    printf("...done\n");
    
    // free memory for weight arrays...
    for (int i=0; i <numWeightVectors; i++)
    {
        for (int j=0; j <numVoxels; j++)
            free(bw_weight_array[i][j]);
        free(bw_weight_array[i]);
    }
    free(bw_weight_array);
    
    // free memory for forward array...
    for (int i=0; i <numWeightVectors; i++)
    {
        for (int j=0; j <numVoxels; j++)
            free(bw_forward_array[i][j]);
        free(bw_forward_array[i]);
    }
    free(bw_forward_array);
    
    return (true);
}
// classic SAM approach
//

bool computeDifferential(double **imageData, char *dsName, ds_params & dsParams, char *cdsName, bool useCovDs, filter_params & fparams, bf_params & bparams, double regularization, int numVoxels, vectorCart *voxelList, vectorCart *normalList, double wStart, double wEnd, double bStart, double bEnd, int imageType )
{
	
	double		**covActive;
	double		**covBaseline;
	double      **covArray;
	double		**icovArray;
	double		*covArrayDiag;
	double      *w;
	
	vectorCart	radial;
	vectorCart	orient;
	int			numWeightVectors;
	bool		optimizeOrientation;

	
	double		lowPass = fparams.hc;
	double		hiPass = fparams.lc;
	bool		computeRMS = false;
	
	if (bparams.type == BF_TYPE_RMS)
		numWeightVectors = 2;
	else
		numWeightVectors = 1;
	
	if (bparams.type == BF_TYPE_OPTIMIZED)
		optimizeOrientation = true;
	else
		optimizeOrientation = false;
	
	if (bparams.type == BF_TYPE_FIXED)
		printf("Using fixed source orientations...\n");
	
	////////////////////////////////////////////////////////
	// For differential we need to covariance matrices for all time windows
	// No way to really optimize this part....
	// ////////////////////////////////////////////////////////
	
	if (useCovDs)
	{
		int numCovSensors = getNumSensors(cdsName, false);
		if ( numCovSensors != dsParams.numSensors)
		{
			printf("Dataset set (%s) and covariance dataset (%s) must have same number of primary sensor channels...\n", dsName, cdsName );
			return(false);
		}		
	}
		
	covArray = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (covArray == NULL)
	{
		printf("memory allocation failed for covariance array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		covArray[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( covArray[i] == NULL)
		{
			printf( "memory allocation failed for covariance array" );
			return(false);
		}
	}
	
 	icovArray = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (icovArray == NULL)
	{
		printf("memory allocation failed for inverse covariance array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		icovArray[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( icovArray[i] == NULL)
		{
			printf( "memory allocation failed for covariance array" );
			return(false);
		}
	}	
	
	// need  active covariance matrix
	covActive = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (covActive == NULL)
	{
		printf("memory allocation failed for covActive array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		covActive[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( covActive[i] == NULL)
		{
			printf( "memory allocation failed for covActive array" );
			return(false);
		}
	}
	// don't need this for pseudoZ but allocate / deallocate anyway...
	covBaseline = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (covBaseline == NULL)
	{
		printf("memory allocation failed for covBaseline array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		covBaseline[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( covBaseline[i] == NULL)
		{
			printf( "memory allocation failed for covBaseline array" );
			return(false);
		}
	}
	
	// if using covariance dataset - compute this first then overwrite active and control arrays
	if (useCovDs)
	{
		// calculate active and control window covariance
		printf("*** computing covariance from dataset %s for weight calculation ...\n", cdsName);		
		if ( !getSensorCovariance(cdsName, wStart, wEnd, covActive, fparams) )
		{
			printf("Error encountered creating covariance... exiting\n");
			return(false);
		}
		// copy to covActive to covArray for weight calculation...
		for (int i = 0; i < dsParams.numSensors; i++)
			for (int j = 0; j < dsParams.numSensors; j++)
				covArray[i][j] = covActive[i][j];
		
		if ( imageType != BF_IMAGE_PSEUDO_Z )
		{
			// calculate baseline window covariance
			if ( !getSensorCovariance(cdsName, bStart, bEnd, covBaseline, fparams) )
			{
				printf("Error encountered creating baseline covariance... exiting\n");
				return(false);
			}
			for (int i = 0; i < dsParams.numSensors; i++)
				for (int j = 0; j < dsParams.numSensors; j++)
					covArray[i][j] += covBaseline[i][j];
			
			for (int i = 0; i < dsParams.numSensors; i++)
				for (int j = 0; j < dsParams.numSensors; j++)
					covArray[i][j] /= 2.0;
		}
	}
	
	// calculate active and control window covariance
	// this will overwrite values above for active and control covariance only
	printf("computing active period covariance ...\n");		
	if ( !getSensorCovariance(dsName, wStart, wEnd, covActive, fparams) )
	{
		printf("Error encountered creating covariance... exiting\n");
		return(false);
	}
	
	if ( imageType != BF_IMAGE_PSEUDO_Z )
	{
		// calculate baseline window covariance
		
		printf("computing baseline period covariance ...\n");		
		if ( !getSensorCovariance(dsName, bStart, bEnd, covBaseline, fparams) )
		{
			printf("Error encountered creating baseline covariance... exiting\n");
			return(false);
		}
		
	}

	if (!useCovDs)
	{
		// get covArray for weight calculation...
		for (int i = 0; i < dsParams.numSensors; i++)
			for (int j = 0; j < dsParams.numSensors; j++)
				covArray[i][j] = covActive[i][j];
		
		if ( imageType != BF_IMAGE_PSEUDO_Z )		// sum with active to create a combined covariance array for weights...
		{
			for (int i = 0; i < dsParams.numSensors; i++)
				for (int j = 0; j < dsParams.numSensors; j++)
					covArray[i][j] += covBaseline[i][j];
			for (int i = 0; i < dsParams.numSensors; i++)
				for (int j = 0; j < dsParams.numSensors; j++)
					covArray[i][j] /= 2.0;
			
		}
	}
		
	if ( regularization != 0.0 )
	{
		covArrayDiag = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if (covArrayDiag == NULL)
		{
			printf("memory allocation failed for covariance array diagonal elements\n");
			return(false);
		}
		
		printf("Regularizing covariance matrix by %g ...Tesla^2\n", regularization);
		// multiply diagonals by constant
		for (int k=0; k<dsParams.numSensors; k++)
		{
			covArrayDiag[k] = covArray[k][k];   // save original values
			covArray[k][k] += regularization;
		}
	}
	
	if ( !invertMatrix(covArray, icovArray, dsParams.numSensors) )
	{
		printf("Error encountered inverting covariance matrix... exiting\n");
		return(false);
	}
	
	// restore non-regularized cov array
	if ( regularization != 0.0 )
	{
		for (int k=0; k<dsParams.numSensors; k++)
			covArray[k][k] = covArrayDiag[k];
		
		free(covArrayDiag);
	}
	
	
	////////////////////////////////////////////////////////////
	// allocate memory for weights array
	////////////////////////////////////////////////////////////
	
	bw_weight_array = (double ***)malloc( sizeof(double **) * numWeightVectors );
	if (bw_weight_array == NULL)
	{
		printf("memory allocation failed for weights array");
		return(false);
	}
	for (int i=0; i <numWeightVectors; i++)
	{
		bw_weight_array[i] = (double **)malloc( sizeof(double *) * numVoxels );
		if ( bw_weight_array[i] == NULL)
		{
			printf( "memory allocation failed for weights array" );
			return(false);
		}
		for (int j=0; j <numVoxels; j++)
		{
			bw_weight_array[i][j] = (double *)malloc( sizeof(double) * dsParams.numSensors );
			if ( bw_weight_array[i][j] == NULL)
			{
				printf( "memory allocation failed for weights array" );
				return(false);
			}
		}  		
	}  
	
	/////////////////////////////
	// compute beamformer weights
	/////////////////////////////
	if ( !computeBeamformerWeights(dsName, dsParams, bw_weight_array, numWeightVectors, covArray, 
								   icovArray, voxelList, normalList, numVoxels, optimizeOrientation) )
	{
		printf("computeBeamformerWeights returned error ...\n");
		return(false);
	}
	
	// Normalize weights
	//
	if (bparams.normalized)
	{
		double BW = lowPass - hiPass;
		double noise = bparams.noiseRMS * bparams.noiseRMS * BW;	// convert noise to power in the bandwidth used
		
		printf("Normalizing weights using mean sensor noise = %g fT per root Hz, (BW = %g Hz)...\n", bparams.noiseRMS * 1e15, BW );
		for (int voxel=0; voxel<numVoxels; voxel++)
		{
			for (int i=0; i<numWeightVectors; i++)
			{			
				double projNoise = 0.0;
				for (int j=0; j<dsParams.numSensors; j++)
					projNoise += bw_weight_array[i][voxel][j] * bw_weight_array[i][voxel][j] * noise;
				// normalize weights
				if ( projNoise != 0.0 )
				{
					for (int j=0; j<dsParams.numSensors; j++)
					{
						bw_weight_array[i][voxel][j] /= sqrt(projNoise);
					}
				}
			}
		}
	}
	

	
	////////////////////////////////////////////////
	// create a single differential image
	////////////////////////////////////////////////   
	int samType;
	double sumPower;
	double sumNoise;
	
	// 1 x numVoxels array for summing power...
	w = (double *)malloc( sizeof(double) * numVoxels );
	if (w == NULL)
	{
		printf("memory allocation failed for w array\n");
		return(false);
	}
	
	if ( imageType == BF_IMAGE_PSEUDO_Z )
		printf("Creating pseudo-Z power image, active window (%.2f to %.2f sec)...\n", wStart, wEnd);
	else if ( imageType == BF_IMAGE_PSEUDO_T )
		printf("Creating differential (pseudo-T) power image, active windoow (%.2f to %.2f s) minus baseline window (%.2f to %.2f s)... \n", wStart, wEnd, bStart, bEnd);
	else if ( imageType == BF_IMAGE_PSEUDO_F )
		printf("Creating differential (pseudo-F) power image, active windoow (%.2f to %.2f s) divided by baseline window (%.2f to %.2f s)... \n", wStart, wEnd, bStart, bEnd);

	for (int voxel=0; voxel<numVoxels; voxel++)
	{
		//  sum power using active window covariance, P = W'.C.W
		double sumPower = 0.0;
		for (int i=0; i<numWeightVectors; i++)
		{
			for (int j=0; j<dsParams.numSensors; j++)
			{
				w[j] = 0.0;			
				for (int k=0; k<dsParams.numSensors; k++)
					w[j] += bw_weight_array[i][voxel][k] * covActive[j][k];
			}
			for (int k=0; k<dsParams.numSensors; k++)
				sumPower += w[k] * bw_weight_array[i][voxel][k];
		}
		
		if (imageType == BF_IMAGE_PSEUDO_Z)
			imageData[0][voxel] = sumPower;
		else
		{
			//  sum power using active window covariance, P = W'.C.W
			double sumControl = 0.0;
			for (int i=0; i<numWeightVectors; i++)
			{
				for (int j=0; j<dsParams.numSensors; j++)
				{
					w[j] = 0.0;			
					for (int k=0; k<dsParams.numSensors; k++)
						w[j] += bw_weight_array[i][voxel][k] * covBaseline[j][k];
				}
				for (int k=0; k<dsParams.numSensors; k++)
					sumControl += w[k] * bw_weight_array[i][voxel][k];
			}
			if (imageType == BF_IMAGE_PSEUDO_T)
				imageData[0][voxel] = sumPower - sumControl;
			else if (imageType == BF_IMAGE_PSEUDO_F)
			{
				// create F stat.
				double f = sumPower / sumControl;
				if ( f > 1.0)
					imageData[0][voxel] = f-1.0;
				else if ( f < 1.0 && f != 0.0 )
					imageData[0][voxel] = 1.0 - (1.0/f);
			}
		}
		
		printPercentDone( voxel+1, numVoxels );
		
	} // next voxel				
	
	// free memory...
	for (int i = 0; i < dsParams.numSensors; i++)
		free(covArray[i]);
	free(covArray);
	
	for (int i = 0; i < dsParams.numSensors; i++)
		free(icovArray[i]);
	free(icovArray);
	
	for (int i = 0; i < dsParams.numSensors; i++)
		free(covActive[i]);
	free(covActive);	

	for (int i = 0; i < dsParams.numSensors; i++)
		free(covBaseline[i]);
	free(covBaseline);	
	
	// free memory for weight arrays...
	for (int i=0; i <numWeightVectors; i++)
	{
		for (int j=0; j <numVoxels; j++)
			free(bw_weight_array[i][j]);  
		free(bw_weight_array[i]);
	}

	free(bw_weight_array);
	
	free(w);
	
	
	
	return (true);
}

// separate version of computeDifferential for using two datasets for time windows
// same arguments as for using a covariance dataset except now cdsName refers to the Control dataset name...

bool computeDifferentialMultiDs(double **imageData, char *dsName, ds_params & dsParams, char *cdsName, filter_params & fparams, bf_params & bparams, double regularization,
						 int numVoxels, vectorCart *voxelList, vectorCart *normalList, double wStart, double wEnd, double bStart, double bEnd, int imageType )
{
	
	double		**covActive;
	double		**covBaseline;
	double      **covArray;
	double		**icovArray;
	double		*covArrayDiag;
	double      *w;
	
	vectorCart	radial;
	vectorCart	orient;
	int			numWeightVectors;
	bool		optimizeOrientation;
	
	
	double		lowPass = fparams.hc;
	double		hiPass = fparams.lc;
	bool		computeRMS = false;

	
	if ( imageType == BF_IMAGE_PSEUDO_Z )
	{
		printf("image type must be differential for computeDifferentialMultiDs ...\n");
		return(false);
	}
	if (bparams.type == BF_TYPE_RMS)
		numWeightVectors = 2;
	else
		numWeightVectors = 1;
	
	if (bparams.type == BF_TYPE_OPTIMIZED)
		optimizeOrientation = true;
	else
		optimizeOrientation = false;
	
	if (bparams.type == BF_TYPE_FIXED)
		printf("Using fixed source orientations...\n");
	
	////////////////////////////////////////////////////////
	// For differential we need to covariance matrices for all time windows
	// No way to really optimize this part....
	// ////////////////////////////////////////////////////////
	
	int numCovSensors = getNumSensors(cdsName, false);
	if ( numCovSensors != dsParams.numSensors)
	{
		printf("Active dataset set (%s) and control dataset (%s) must have same number of primary sensor channels...\n", dsName, cdsName );
		return(false);
	}
	
	covArray = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (covArray == NULL)
	{
		printf("memory allocation failed for covariance array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		covArray[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( covArray[i] == NULL)
		{
			printf( "memory allocation failed for covariance array" );
			return(false);
		}
	}
	
 	icovArray = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (icovArray == NULL)
	{
		printf("memory allocation failed for inverse covariance array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		icovArray[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( icovArray[i] == NULL)
		{
			printf( "memory allocation failed for covariance array" );
			return(false);
		}
	}
	
	// need  active covariance matrix
	covActive = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (covActive == NULL)
	{
		printf("memory allocation failed for covActive array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		covActive[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( covActive[i] == NULL)
		{
			printf( "memory allocation failed for covActive array" );
			return(false);
		}
	}
	// don't need this for pseudoZ but allocate / deallocate anyway...
	covBaseline = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (covBaseline == NULL)
	{
		printf("memory allocation failed for covBaseline array");
		return(false);
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		covBaseline[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( covBaseline[i] == NULL)
		{
			printf( "memory allocation failed for covBaseline array" );
			return(false);
		}
	}
	
	// if using covariance dataset - compute this first then overwrite active and control arrays

	// calculate active and control window covariance
	printf("*** computing active covariance from dataset %s for weight calculation ...\n", dsName);
	if ( !getSensorCovariance(dsName, wStart, wEnd, covActive, fparams) )
	{
		printf("Error encountered creating covariance... exiting\n");
		return(false);
	}
	// copy to covActive to covArray for weight calculation...
	for (int i = 0; i < dsParams.numSensors; i++)
		for (int j = 0; j < dsParams.numSensors; j++)
			covArray[i][j] = covActive[i][j];
		
	// calculate baseline window covariance
	printf("*** computing baseline covariance from dataset %s for weight calculation ...\n", cdsName);
	if ( !getSensorCovariance(cdsName, bStart, bEnd, covBaseline, fparams) )
	{
		printf("Error encountered creating baseline covariance... exiting\n");
		return(false);
	}
	
	// add to covariance array for weights
	for (int i = 0; i < dsParams.numSensors; i++)
		for (int j = 0; j < dsParams.numSensors; j++)
			covArray[i][j] += covBaseline[i][j];
	
	for (int i = 0; i < dsParams.numSensors; i++)
		for (int j = 0; j < dsParams.numSensors; j++)
			covArray[i][j] /= 2.0;
		
	if ( regularization != 0.0 )
	{
		covArrayDiag = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if (covArrayDiag == NULL)
		{
			printf("memory allocation failed for covariance array diagonal elements\n");
			return(false);
		}
		
		printf("Regularizing covariance matrix by %g ...Tesla^2\n", regularization);
		// multiply diagonals by constant
		for (int k=0; k<dsParams.numSensors; k++)
		{
			covArrayDiag[k] = covArray[k][k];   // save original values
			covArray[k][k] += regularization;
		}
	}
	
	if ( !invertMatrix(covArray, icovArray, dsParams.numSensors) )
	{
		printf("Error encountered inverting covariance matrix... exiting\n");
		return(false);
	}
	
	// restore non-regularized cov array
	if ( regularization != 0.0 )
	{
		for (int k=0; k<dsParams.numSensors; k++)
			covArray[k][k] = covArrayDiag[k];
		
		free(covArrayDiag);
	}
	
	////////////////////////////////////////////////////////////
	// allocate memory for weights array
	////////////////////////////////////////////////////////////
	
	bw_weight_array = (double ***)malloc( sizeof(double **) * numWeightVectors );
	if (bw_weight_array == NULL)
	{
		printf("memory allocation failed for weights array");
		return(false);
	}
	for (int i=0; i <numWeightVectors; i++)
	{
		bw_weight_array[i] = (double **)malloc( sizeof(double *) * numVoxels );
		if ( bw_weight_array[i] == NULL)
		{
			printf( "memory allocation failed for weights array" );
			return(false);
		}
		for (int j=0; j <numVoxels; j++)
		{
			bw_weight_array[i][j] = (double *)malloc( sizeof(double) * dsParams.numSensors );
			if ( bw_weight_array[i][j] == NULL)
			{
				printf( "memory allocation failed for weights array" );
				return(false);
			}
		}
	}
	
	/////////////////////////////
	// compute beamformer weights
	/////////////////////////////
	if ( !computeBeamformerWeights(dsName, dsParams, bw_weight_array, numWeightVectors, covArray,
								   icovArray, voxelList, normalList, numVoxels, optimizeOrientation) )
	{
		printf("computeBeamformerWeights returned error ...\n");
		return(false);
	}
	
	// Normalize weights
	//
	if (bparams.normalized)
	{
		double BW = lowPass - hiPass;
		double noise = bparams.noiseRMS * bparams.noiseRMS * BW;	// convert noise to power in the bandwidth used
		
		printf("Normalizing weights using mean sensor noise = %g fT per root Hz, (BW = %g Hz)...\n", bparams.noiseRMS * 1e15, BW );
		for (int voxel=0; voxel<numVoxels; voxel++)
		{
			for (int i=0; i<numWeightVectors; i++)
			{
				double projNoise = 0.0;
				for (int j=0; j<dsParams.numSensors; j++)
					projNoise += bw_weight_array[i][voxel][j] * bw_weight_array[i][voxel][j] * noise;
				// normalize weights
				if ( projNoise != 0.0 )
				{
					for (int j=0; j<dsParams.numSensors; j++)
					{
						bw_weight_array[i][voxel][j] /= sqrt(projNoise);
					}
				}
			}
		}
	}
	
	
	
	////////////////////////////////////////////////
	// create a single differential image
	////////////////////////////////////////////////
	int samType;
	double sumPower;
	double sumNoise;
	
	// 1 x numVoxels array for summing power...
	w = (double *)malloc( sizeof(double) * numVoxels );
	if (w == NULL)
	{
		printf("memory allocation failed for w array\n");
		return(false);
	}
	
	if ( imageType == BF_IMAGE_PSEUDO_T )
		printf("Creating differential (pseudo-T) power image, active windoow (%s, %.2f to %.2f s) minus baseline window (%s, %.2f to %.2f s)... \n", dsName, wStart, wEnd, cdsName, bStart, bEnd);
	else
		printf("Creating differential (pseudo-F) power image, active windoow (%s, %.2f to %.2f s) divided by baseline window (%s, %.2f to %.2f s)... \n", dsName, wStart, wEnd, cdsName, bStart, bEnd);
	
	for (int voxel=0; voxel<numVoxels; voxel++)
	{
		//  sum power using active window covariance, P = W'.C.W
		double sumPower = 0.0;
		for (int i=0; i<numWeightVectors; i++)
		{
			for (int j=0; j<dsParams.numSensors; j++)
			{
				w[j] = 0.0;
				for (int k=0; k<dsParams.numSensors; k++)
					w[j] += bw_weight_array[i][voxel][k] * covActive[j][k];
			}
			for (int k=0; k<dsParams.numSensors; k++)
				sumPower += w[k] * bw_weight_array[i][voxel][k];
		}
		
		//  sum power using active window covariance, P = W'.C.W
		double sumControl = 0.0;
		for (int i=0; i<numWeightVectors; i++)
		{
			for (int j=0; j<dsParams.numSensors; j++)
			{
				w[j] = 0.0;
				for (int k=0; k<dsParams.numSensors; k++)
					w[j] += bw_weight_array[i][voxel][k] * covBaseline[j][k];
			}
			for (int k=0; k<dsParams.numSensors; k++)
				sumControl += w[k] * bw_weight_array[i][voxel][k];
		}
		if (imageType == BF_IMAGE_PSEUDO_T)
			imageData[0][voxel] = sumPower - sumControl;
		else if (imageType == BF_IMAGE_PSEUDO_F)
		{
			// create F stat.
			double f = sumPower / sumControl;
			if ( f > 1.0)
				imageData[0][voxel] = f-1.0;
			else if ( f < 1.0 && f != 0.0 )
				imageData[0][voxel] = 1.0 - (1.0/f);
		}
		
		printPercentDone( voxel+1, numVoxels );
		
	} // next voxel
	
	// free memory...
	for (int i = 0; i < dsParams.numSensors; i++)
		free(covArray[i]);
	free(covArray);
	
	for (int i = 0; i < dsParams.numSensors; i++)
		free(icovArray[i]);
	free(icovArray);
	
	for (int i = 0; i < dsParams.numSensors; i++)
		free(covActive[i]);
	free(covActive);
	
	for (int i = 0; i < dsParams.numSensors; i++)
		free(covBaseline[i]);
	free(covBaseline);
	
	// free memory for weight arrays...
	for (int i=0; i <numWeightVectors; i++)
	{
		for (int j=0; j <numVoxels; j++)
			free(bw_weight_array[i][j]);
		free(bw_weight_array[i]);
	}
	
	free(bw_weight_array);
	
	free(w);
	
	
	
	return (true);
}


// ** moved from datasetUtils/computeCovariance.cc

void *covThread(void *threadArg)
{  
	
	thread_cov_t *threadData = (thread_cov_t *) threadArg;
	int threadID = threadData->threadID;
	int trialStart = threadData->trialStart;
	int trialEnd = threadData->trialEnd;
	//printf("Thread %d: trialStart=%d  trialEnd=%d\n", threadID, trialStart, trialEnd-1);
	
	// Allocate memory
	
	double **trialData = (double **)malloc( sizeof(double *) * s_dsParams.numSensors );
	if ( trialData == NULL)
    {
		printf("memory allocation failed for trial array\n");
		abort();
    }
	for (int i=0; i<s_dsParams.numSensors; i++) 
    {
		trialData[i] = (double *)malloc( sizeof(double) * s_dsParams.numSamples);
		if ( trialData[i] == NULL)
		{
			printf("memory allocation failed for trial array\n");
			abort();
		}
    }
	
	double **cov = (double **)malloc( sizeof(double *) * s_dsParams.numSensors );
	if ( cov == NULL)
	{
		printf("memory allocation failed for trial array\n");
		abort();
	}
	for (int i=0; i<s_dsParams.numSensors; i++) 
	{
		cov[i] = (double *)malloc( sizeof(double) * s_dsParams.numSensors);
		if ( cov[i] == NULL)
		{
			printf("memory allocation failed for cov array\n");
			abort();
		}
	}
	
	double *meanArray = (double *)malloc( sizeof(double) * s_dsParams.numSensors );
	if ( meanArray == NULL)
	{
		printf("memory allocation failed for meanArrayArray\n");
		abort();
	}
	
	// do the trials assigned to this thread....
	
	for (int trial=trialStart; trial<trialEnd; trial++)
	{
		
		// Read trial data  
		if(!readMEGTrialData(dsNamePtr, s_dsParams, trialData, trial, s_selectedGradient, true ))
		{
			fprintf(stderr,"\nFailed reading data in readMEGTrialData\n");
			abort();
		}
		
		// Filter whole trial for each channel
		if (fparamsPtr->enable)
		{
			double * channelData = (double *)malloc( sizeof(double) * s_dsParams.numSamples );
			if ( channelData == NULL)
			{
				printf("memory allocation failed\n");
				abort();
			}
			for (int i=0; i < s_dsParams.numSensors; i++)
			{			  
				// Apply filter - routine will remove offset first
				for (int k=0; k< s_dsParams.numSamples; k++)
					channelData[k] = trialData[i][k];
				
				pthread_mutex_lock(&covArrayMutex);
				applyFilter( channelData, trialData[i], s_dsParams.numSamples, fparamsPtr);
				pthread_mutex_unlock(&covArrayMutex);
			}
			
			free( channelData );
		}
		
		// Compute meanArray for each channel for this trial in the window specified
		for (int i=0; i < s_dsParams.numSensors; i++)
			meanArray[i] = 0.0;		
		for (int i=0; i < s_dsParams.numSensors; i++)
		{
			for (int k=s_startSample; k<= s_endSample; k++)
				meanArray[i] += trialData[i][k];
			meanArray[i] /= s_windowLength;
		}
		
		// Compute the covariance for this trial 
		// -- to save time compute only lower diagonal of symmetric matrix	
		for (int i=0; i < s_dsParams.numSensors; i++)
		{
			for (int j=0; j <= i; j++)
			{
				double sumDiff = 0.0;
				for (int k=s_startSample; k<=s_endSample; k++)
				{
					double d1 = trialData[i][k] - meanArray[i];
					double d2 = trialData[j][k] - meanArray[j];
					sumDiff += d1 * d2;	
				}
				cov[i][j] = sumDiff;	
			}
		}
		
		// Divide by window sample number 
		
		for (int i=0; i < s_dsParams.numSensors; i++)
		{
			for (int j=0; j <= i; j++)
			{
				cov[i][j] /= (double)s_windowLength;	
			}
		}
		
		
		// Now fill in upper diagonal of symmetric matrix  
		// -- this is faster than computing it!
		// 
		for (int i=0; i < s_dsParams.numSensors; i++)
			for (int j=i+1; j < s_dsParams.numSensors; j++)
				cov[i][j] = cov[j][i];
		
		// Lock the mutex and update shared variables
		
		pthread_mutex_lock(&covArrayMutex);
		
		s_totTrials++;
		
		// Sum this trial covariance into total 
		
		for (int i=0; i < s_dsParams.numSensors; i++)
			for (int j=0; j < s_dsParams.numSensors; j++)
				covArrayPtr[i][j] += cov[i][j];
		
		pthread_mutex_unlock(&covArrayMutex);
		
		printf("\b\b\b\b%4d", s_totTrials);
		
		fflush(stdout);
		
	}
	
	// Free all arrays
	
	for (int i=0; i<s_dsParams.numSensors; i++) 
		free( trialData[i] );
	free( trialData );	
	
	for (int i=0; i<s_dsParams.numSensors; i++) 
		free( cov[i] );
	free( cov );
	
	
	free( meanArray );
	
	
	pthread_exit((void *) 0);
	
    return 0;
}

bool getSensorCovariance(char *dsName, double wStart, double wEnd, double **covArray, filter_params &fparams)
{
	
	if ( covArray == NULL )
    {
		printf("Null pointer encountered in getCovarianceArray() \n");
		return(false);
    }
	
	// Get the dataset parameters
	
	if ( !readMEGResFile( dsName, s_dsParams) )	
    {
		printf("Could not open MEG resource in dataset [%s]\n", dsName);
		return(false);
    }
	
	// set static variables
	
	printf("computing %d by %d covariance matrix from %s\n", s_dsParams.numSensors, s_dsParams.numSensors, dsName);
	
	// Set thread attributes to be joinable
	
	pthread_attr_t attr;
	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
	
	// Initialize the mutex
	
	pthread_mutex_init(&covArrayMutex, NULL);
	
	// Check boundaries
	
	double numpts;
	numpts = s_dsParams.sampleRate * wStart;
	s_startSample = s_dsParams.numPreTrig + (int)numpts;
	
	numpts = s_dsParams.sampleRate * wEnd;
	s_endSample = s_dsParams.numPreTrig + (int)numpts;
	
	printf("using time window of %g s (sample %d) to %g s (sample %d)\n", 
		   wStart, s_startSample+1, wEnd, s_endSample+1);
	
	if ( s_startSample < 0 )
	{
		printf("Window time %g s  (sample %d) outside of trial boundary\n", wStart, s_startSample+1);
		return(false);
	}
	if ( s_endSample >= s_dsParams.numSamples )
	{
		printf("Window time %g s (sample %d) outside of trial boundary\n", wEnd, s_endSample+1);
		return(false);
	}
	
	s_windowLength = s_endSample - s_startSample + 1;
	
	if ( s_windowLength < 1 )
	{
		printf("Invalid window length <%g>\n", wStart);
		return(false);
	}
	
	// Zero covariance array
	
	for (int i=0; i < s_dsParams.numSensors; i++)
		for (int j=0; j < s_dsParams.numSensors; j++)
			covArray[i][j] = 0.0;  
	
	printf("Reading and filtering trial:    \n");
	
	// Divide the trials into threads
	
	
	int trialsPerThread;
	if( s_dsParams.numTrials < NUM_COV_THREADS )
	{
		trialsPerThread = 1;
	}
	else
	{
		trialsPerThread = s_dsParams.numTrials/NUM_COV_THREADS;
	}
	int trialStart = 0;
	int trialEnd = trialsPerThread;
	if ( trialEnd > s_dsParams.numTrials) 
		trialEnd = s_dsParams.numTrials;
	
	thread_cov_t covThreadData[NUM_COV_THREADS];
	
	// Calculate the covariance
	
	// set static variables reference in threaded routine above
	covArrayPtr = covArray;
	dsNamePtr = dsName;
	fparamsPtr = &fparams;
	
	int numActualThreads = 0;
	for (int iThread=0; iThread<NUM_COV_THREADS; iThread++)
	{
		numActualThreads++;
		covThreadData[iThread].threadID = iThread;
		covThreadData[iThread].trialStart = trialStart;
		covThreadData[iThread].trialEnd = trialEnd;
		
		//printf("iThread = %d, trialStart = %d, trialEnd = %d\n", iThread, trialStart, trialEnd-1);
		
		int rc = pthread_create(&covThreads[iThread], &attr, covThread, (void *) &covThreadData[iThread]);
		if (rc) 
		{
			printf("ERROR; return code from pthread_create() is %d\n", rc);
			return false;
		}
		
		trialStart += trialsPerThread;
		if( trialStart >= s_dsParams.numTrials ) 
			break;
		trialEnd += trialsPerThread;
		if( trialEnd > s_dsParams.numTrials ) 
			trialEnd = s_dsParams.numTrials;
		// if( (numTrials-trialEnd) < trialsPerThread ) trialEnd = numTrials;
		if( iThread==(NUM_COV_THREADS-2) ) 
			trialEnd = s_dsParams.numTrials;
	}
	
	// Join all threads
	
	for (int iThread=0; iThread<numActualThreads; iThread++)
	{
		int status;
		int rc = pthread_join(covThreads[iThread], (void **)&status);
		if (rc)
		{
			printf("ERROR return code from pthread_join() is %d\n", rc);
			return false;
		}
		// printf("Completed join with thread %d status= %d\n",iThread, status);
		
	}
	
	//sleep(180);
	
	// Normalize by number of trials
	
	for (int i=0; i < s_dsParams.numSensors; i++)
		for (int j=0; j < s_dsParams.numSensors; j++)
			covArray[i][j] = covArrayPtr[i][j]/(double)s_dsParams.numTrials;
	
	// print mean covariance - useful for regularizing
	double meanCov = 0.0;
	for (int i=0; i < s_dsParams.numSensors; i++)
		meanCov += covArray[i][i];
	meanCov = meanCov / s_dsParams.numSensors;
	
	printf("Mean sensor variance = %.3e Tesla^2\n", meanCov);
	
	// Free threading resources, moved by zhengkai
	
	pthread_attr_destroy(&attr);
	pthread_mutex_destroy(&covArrayMutex);
	
	printf("...done\n");	
	return(true);
}

// ****
// moved here from datasetUtils

////////////////////////////////////////////////////////
// ** routine computes average for all trials 
// and returns it in pointer array
// excludes references!
///////////////////////////////////////////////////////

bool getSensorDataAverage(char *dsName, ds_params & dsParams, double **megAve, filter_params &fparams)
{
	double			mean;
 	int				selectedGradient = -1;
  	bool			sensorsOnly = true;
	
	if ( megAve == NULL )
	{
		printf("Null pointer encountered in getSensorDataAverage() \n");
		return(false);
	}
	
	printf("computing MEG average data \n");
	
	// get dsParams for sensors only
	
	if ( !readMEGResFile( dsName, dsParams) )
	{
		printf("Error reading res4 file for virtual sensors\n");
		return(false);
	}
	
	// need arrays for data and average etc...
	//
	
	// NOTE used to read res4 with sensors only so that numChannels = numSensors
	// to allocate only memory for sensors, instead use dsParams.numSensors
	
	bw_sensorData = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (bw_sensorData == NULL)
	{
		printf("memory allocation failed for trial array");
		return(false);
	}
	
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		bw_sensorData[i] = (double *)malloc( sizeof(double) * dsParams.numSamples);
		if ( bw_sensorData[i] == NULL)
		{
			printf( "memory allocation failed for trial array" );
			return(false);
		}
	}
	
	// zero average buffer
	for (int i=0; i < dsParams.numSensors; i++)
		for (int j=0; j < dsParams.numSamples; j++)
			megAve[i][j] = 0.0;
	
	// average across all trials in dataset
	for (int i=0; i < dsParams.numTrials; i++)
	{
		if ( !readMEGTrialData( dsName, dsParams, bw_sensorData, i, selectedGradient, sensorsOnly) )
		{
			printf("Error reading .meg4 file\n");
			return(false);
		}
		
		for (int j=0; j < dsParams.numSensors; j++)
		{
			// compute average MEG
			for (int k=0; k< dsParams.numSamples; k++)
				megAve[j][k] += bw_sensorData[j][k];
		}
	}
	
	// divide ave by N trials
	for (int j=0; j < dsParams.numSensors; j++)
		for (int k=0; k< dsParams.numSamples; k++)
			megAve[j][k] /= (double)dsParams.numTrials;	
	
	// filter the average
	if (fparams.enable)
	{
		printf("filtering data (%g Hz to %g Hz) \n", fparams.lc, fparams.hc);
		for (int j=0; j < dsParams.numSensors; j++)
		{		
			double * aveData = (double *)malloc( sizeof(double) * dsParams.numSamples );
			if (aveData == NULL)
			{
				printf("memory allocation failed for ave array");
				return(false);
			}
			for (int k=0; k< dsParams.numSamples; k++)
				aveData[k] = megAve[j][k];
			
			applyFilter( aveData, megAve[j], dsParams.numSamples, &fparams);
			free( aveData );
		}
	}
	
	printf("freeing memory...\n");
	for (int i=0; i<dsParams.numSensors; i++) 
		free( bw_sensorData[i] );
	
	free( bw_sensorData );	
	
	return (true);
}


bool getSensorDataPlusMinusAverage(char *dsName, ds_params & dsParams, double **megAve, filter_params &fparams)
{
	
	double 		mean;
 	int			selectedGradient = -1;
 	bool		sensorsOnly = true;
	
	if ( megAve == NULL )
	{
		printf("Null pointer encountered in getSensorDataPlusMinusAverage() \n");
		return(false);
	}
	
	printf("computing MEG plus-minus average data \n");
	
	// get dsParams for sensors only
	
	if ( !readMEGResFile( dsName, dsParams) )
	{
		printf("Error reading res4 file for virtual sensors\n");
		exit(0);
	}
	
	// need arrays for data and average etc...
	//
	bw_sensorData = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (bw_sensorData == NULL)
	{
		printf("memory allocation failed for trial array");
		exit(0);
	}
	
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		bw_sensorData[i] = (double *)malloc( sizeof(double) * dsParams.numSamples);
		if ( bw_sensorData[i] == NULL)
		{
			printf( "memory allocation failed for trial array" );
			exit(0);
		}
	}
	
	// zero average buffer
	for (int i=0; i < dsParams.numSensors; i++)
		for (int j=0; j < dsParams.numSamples; j++)
			megAve[i][j] = 0.0;
	
	// average across all trials in dataset
	// if not even number drop one trial
	
	int numTrialsToAverage = dsParams.numTrials;
	
	if ( numTrialsToAverage%2 )
		numTrialsToAverage--;
	
	for (int i=0; i < numTrialsToAverage; i++)
	{
		if ( !readMEGTrialData( dsName, dsParams, bw_sensorData, i, selectedGradient, sensorsOnly) )
		{
			printf("Error reading .meg4 file\n");
			exit(0);
		}
		
		for (int j=0; j < dsParams.numSensors; j++)
		{
			// compute average MEG
			for (int k=0; k< dsParams.numSamples; k++)
			{
				if ( i%2 )
					megAve[j][k] += bw_sensorData[j][k];
				else
					megAve[j][k] -= bw_sensorData[j][k];
			}
		}
	}
	
	// divide ave by N trials
	for (int j=0; j < dsParams.numSensors; j++)
		for (int k=0; k< dsParams.numSamples; k++)
			megAve[j][k] /= (double)numTrialsToAverage;	
	
	// filter average	
	if (fparams.enable)
	{
		printf("filtering data (%g Hz to %g Hz) \n", fparams.lc, fparams.hc);
		double * aveData = (double *)malloc( sizeof(double) * dsParams.numSamples );
		if (aveData == NULL)
		{
			printf("memory allocation failed for ave array");
			exit(0);
		}
		for (int j=0; j < dsParams.numSensors; j++)
		{
			// filter data -- need temp array to hold unfiltered data
			//
			for (int k=0; k< dsParams.numSamples; k++)
				aveData[k] = megAve[j][k];
			applyFilter( aveData, megAve[j], dsParams.numSamples, &fparams);
		}
		free( aveData );
	}
	
	printf("freeing memory...\n");
	for (int i=0; i<dsParams.numSensors; i++) 
		free( bw_sensorData[i] );
	
	free( bw_sensorData );	
	
	
	return (true);
}

// get a single trial of filtered data -- sensors only 
// -- do this in silent mode as may be repeated n trials times...

bool getSensorData(char *dsName, ds_params & dsParams, double **megTrial, int trial, filter_params &fparams)
{
	double 		mean;
 	int			selectedGradient = -1;
	bool		sensorsOnly = true;
	
	if ( megTrial == NULL )
	{
		printf("Null pointer encountered in getSensorDataAverage() \n");
		return(false);
	}
	
	// get dsParams for sensors only
	
	if ( !readMEGResFile( dsName, dsParams) )
	{
		printf("Error reading res4 file for virtual sensors\n");
		exit(0);
	}
	
	
	if ( !readMEGTrialData( dsName, dsParams, megTrial, trial, selectedGradient, true) )
	{
		printf("Error reading .meg4 file\n");
		exit(0);
	}
	
	
	if (fparams.enable)
	{
		double * trialData = (double *)malloc( sizeof(double) * dsParams.numSamples );
		if (trialData == NULL)
		{
			printf("memory allocation failed for ave array");
			exit(0);
		}
		for (int j=0; j < dsParams.numSensors; j++)
		{
			for (int k=0; k< dsParams.numSamples; k++)
				trialData[k] = megTrial[j][k];
			
			applyFilter( trialData, megTrial[j], dsParams.numSamples, &fparams);
		}
		free( trialData );
	}
	
	
	
	return (true);
	
}


