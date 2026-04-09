/////////////////////////////////////////////////////////////////////////////////////////////////////////
//		sourceUtils.cc
//
//		source code for MEG source analysis routines. 
//
//		(c) Douglas O. Cheyne, 2005-2020  All rights reserved.
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
//		Feb 26, 2010			-- new version, moved everything from old sourceUtils to main library directory, includes multithreading of LCMV weights.
//
//      April 6, 2010          -- now passes cov and icov to weights routine which is simplified and can compute direction on separate data covariance
//
//      May 10, 2010			-- added computeVS function for mex functions - adapted from makeVS.cc which was stand-alone C program.
//
//      July 27, 2010			-- added ability to write and read data average and covariance data from disk files to speed up makeVS.
//			
//		May 11, 2012			-- ***** major changes ******
//								-- Moved all the beamformer code to another library (bwlib)  Kept forward solution code here for simDs
//
//		April 30, 2020			-- added routines for magnetic dipole and simplex fitting, modified computeForwardSolution

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <sys/stat.h>
#include <time.h>
#include "../headers/sourceUtils.h"
#include "../headers/BWFilter.h"
#include "../headers/path.h"//File separator defined file, added by zhengkai

// Globals for random generator functions
#define IA 16807
#define IM 2147483647
#define AM (1.0/IM)
#define IQ 127773
#define IR 2836
#define NTAB 32
#define NDIV (1+(IM-1)/NTAB)
#define EPS 1.2e-7
#define RNMX (1.0-EPS)


// global variable for for data trial array
//
static long gSeed;	
static int compareDouble( const void *p1, const void *p2 );

// global variables for makeVS
double 		**trialData; 
double		***weight_array;

// 	Numerical Recipes routines for generating random numbers with
//	normal and gaussian distributions 
	
/* (C) Copr. 1986-92 Numerical Recipes Software H. */
// returns deviate with Gaussian probability (var = 1.0)
	
// initialize seed value for random number generator
// this is only used once 

void printPercentDone( int iter, int numIter)
{
	static int lastPercent = 0;

	int percentDone = (int)( ( (double)iter / (double)numIter ) * 100.0 );
	if ( percentDone != lastPercent )
	{
			if ( lastPercent > 0 )
					printf("%c%c%c%c", 0x08,0x08,0x08,0x08 );
			lastPercent = percentDone;
			printf( "%2d %%", percentDone );
			fflush(stdout);
	}
	
	// reset when done
	if ( iter == numIter )
			lastPercent = 0;
}


void sortDoubleArray( double *vector, int vectorSize)
{
        qsort( (void *)vector, (size_t)vectorSize, sizeof( double ), compareDouble );      
}

static int compareDouble( const void *p1, const void *p2 )
{
	double *d1 = (double *)p1;
	double *d2 = (double *)p2;
	
	if ( *d1 < *d2 )
		return -1;
	else if ( *d1 > *d2 ) 
		return 1;
	else
		return 0;
}

void initGaussianDeviate(void)
{
	time_t	tm;
	time(&tm);

	gSeed = -(long)tm;
}

// returns a uniform deviate between 0 and 1
double getRandom(void)
{
	static int initialized = 0;
	time_t	tm;
	
	if ( initialized == 0 )
	{
		time(&tm);
		gSeed = -(long)tm;
		initialized = 1;
	}

	double num = ran1(&gSeed);
	
	return (num);
}

// returns a gaussian distributed deviate between -1 and 1
double getGaussianDeviate(void)
{

	static long iset=0;
	static double gset;
	double fac,rsq,v1,v2;

	if  (iset == 0) 
	{
		do 
		{
			v1=2.0*ran1(&gSeed)-1.0;
			v2=2.0*ran1(&gSeed)-1.0;
			rsq=v1*v1+v2*v2;
		} while (rsq >= 1.0 || rsq == 0.0);
		fac=sqrt(-2.0*log(rsq)/rsq);
		gset=v1*fac;
		iset=1;
		return v2*fac;
	} else 
	{
		iset=0;
		return gset;
	}
}

// 	returns deviate with random probability between 0 and 1.0
//	idum is the seed and should be a negative integer (use system time)
double ran1(long *idum)
{
	int j;
	long k;
	static long iy=0;
	static long iv[NTAB];
	double temp;

	if (*idum <= 0 || !iy) 
	{
		if (-(*idum) < 1) *idum=1;
		else *idum = -(*idum);
		for (j=NTAB+7;j>=0;j--) 
		{
			k=(*idum)/IQ;
			*idum=IA*(*idum-k*IQ)-IR*k;
			if (*idum < 0) *idum += IM;
			if (j < NTAB) iv[j] = *idum;
		}
		iy=iv[0];
	}
	k=(*idum)/IQ;
	*idum=IA*(*idum-k*IQ)-IR*k;
	if (*idum < 0) *idum += IM;
	j=iy/NDIV;
	iy=iv[j];
	iv[j] = *idum;
	if ((temp=AM*iy) > RNMX) return RNMX;
	else return temp;
}


// routine to init spherical models for a ds_params struct with either the passed single sphere, or headmodel file (if useHdmFile set to true)

bool init_dsParams( ds_params & dsParams, double *sphereX, double *sphereY, double *sphereZ,  char *hdmFile, bool useHdmFile )
{
	// init spheres for all channels
	if ( !useHdmFile )
	{
		printf("Initializing single sphere model (x=%g, y=%g, z=%g)\n", *sphereX, *sphereY, *sphereZ);                
		
		for (int i=0; i < dsParams.numChannels; i++)
        {
			if ( dsParams.channel[i].isSensor || dsParams.channel[i].isBalancingRef ) 
			{
				dsParams.channel[i].sphereX = *sphereX;
				dsParams.channel[i].sphereY = *sphereY;
				dsParams.channel[i].sphereZ = *sphereZ;
			}
		}
	}
	else
	{
		vectorCart meanSphere;
	
		if (!readHdmFile( hdmFile, dsParams, sphereX, sphereY, sphereZ) )
		{
			printf("Error returned from readHdmFile\n");
			return(false);
		}
		
		printf("Mean sphere center for tangential constraint is (x=%g, y=%g, z=%g)\n", *sphereX, *sphereY, *sphereZ);                
			
	}
		
	return(true);
}

bool readHdmFile( char *fileName, ds_params & dsParams,  double *sphereX, double *sphereY, double *sphereZ )
{
	FILE    *fp;
	double  dx;
	double  dy;
	double  dz;
	char    name[256];
	char    s[256];
	char    s2[256];
	char    *test;
	
	
	// specify multisphere file here
	fp = fopen(fileName, "r");
	if (fp == NULL)
	{
			printf("Couldn't open multisphere file %s\n", fileName);
			return(false);
	}
	
	printf("Reading sphere(s) from hdm file %s...\n", fileName);
	
	double x1;
	double y1;
	double z1;
	bool hasSingleOrigin = true;
	
	vectorCart meanSphere;

	meanSphere.x = 0.0;
	meanSphere.y = 0.0;
	meanSphere.z = 0.0;
	int sphereCount = 0;
	
	for (int i=0; i < dsParams.numChannels; i++)
	{
		if ( dsParams.channel[i].isSensor || dsParams.channel[i].isBalancingRef ) 
		{
			// scan multisphere file for channel name and get sphere.....
			
			rewind(fp);
			bool foundSphere = false;
			while (!feof(fp))
			{
				char *cout = fgets(s, 256, fp);
				strcpy(s2,s);
				//printf("%s\n", s2);		
					
				test=strtok(s2,":");
				test=strtok(NULL,":");
				
				// bug fix by Teresa Cheung - June, 2011
				// was not correctly ignoring other stuff in CTF versions of the .hdm file format
				
				// need to ignore colon at end of name in hdmFile
				// note fixing to 5 characters causes problems for other system configurations...
				if (test !=NULL)
				{
					sscanf(s, "%s %lf %lf %lf", name, &dx, &dy, &dz);
					
					int len = strlen(name)-1;   
				
					if (!strncmp(dsParams.channel[i].name, name, len))
					{
						dsParams.channel[i].sphereX = dx;
						dsParams.channel[i].sphereY = dy;
						dsParams.channel[i].sphereZ = dz;
						foundSphere = true;
						sphereCount++;
						
						meanSphere.x += dx;
						meanSphere.y += dy;
						meanSphere.z += dz;
						
						if (sphereCount==1)
						{
							x1 = dx;
							y1 = dy;
							z1 = dz;
						}
						else
						{
							if (x1 !=dx || y1 !=dy || z1!= dz)
								hasSingleOrigin = false;
						}
						break;
					}
				}
			}
			
			if (!foundSphere)
			{
					printf("Couldn't find sphere params for channel %s\n", dsParams.channel[i].name);
					fclose(fp);
					return(false);
			}
			
			// debug
			//printf("sphere for channel %s is %g %g %g\n", dsParams.channel[i].name, dx, dy, dz);		
		}
	}
	fclose(fp);
	
	*sphereX = meanSphere.x / sphereCount;
	*sphereY = meanSphere.y / sphereCount;
	*sphereZ = meanSphere.z / sphereCount;
		 
	if (hasSingleOrigin)
		printf("** hdm file specifies a single sphere for all sensors ...\n");
	else
		printf("hdm file specifies multiple spheres for all sensors ...\n");

	return (true);
}                                        

/*
 Compute forward solution for entire sensor array specified in dsParams.
 1. assumes dipole is passed with moment specified in nano-Ampere meters and location vector in cm.
 2. assumes that sphere origins have already been assigned to each sensor (channel.sphereX, channel.sphereX, channel.sphereZ)
 For multiple (overlapping) sphere model, there are different spheres for each senso and for single sphere model these are set to all the same origin. 
 
 - returns field values in dipPattern. array 
 - includes the balancing reference channels if includeBalancingRefs set to true
 */ 

//  April 2020, Modified computeForwardSolution with flags for magnetic dipole calculation or to use dewar coordinates.
//  original computeForwardSolution kept for backwards compatibility

bool computeForwardSolution( const ds_params & dsParams,
							const dip_params & dipole,
							double *dipPattern,
							bool includeBalancingRefs,
							int gradient,
							bool computeMagnetic,
							bool useDewar
							)
{
	char chanName[256];
	int sensorCount = 0;
	double referenceData[MAX_BALANCING];
	
	// Nov - 2010 - had to modify this to use separate lists for 1st/2nd and 3rd grad since they can sometimes be save in different order!
	//            - also made loops more efficient
	
	if (gradient < 0 || gradient > 4)
	{
		printf("Unknown gradient index %d passed to computeForwardSolution\n", gradient);
		return(false);
	}
	
	// get reference channel field in correct order of coef list
	if ( gradient == 1 || gradient == 2 )
	{
		for (int k=0; k<dsParams.numG1Coefs; k++)
		{
			for (int i = 0; i < dsParams.numChannels; i++)
			{
				if ( dsParams.channel[i].isBalancingRef )
				{
					if ( !strncmp(dsParams.g1List[k], dsParams.channel[i].name, 5) )
					{
						if (computeMagnetic)
							referenceData[k] = computeFieldMagnetic( dipole, dsParams.channel[i], useDewar);
						else
							referenceData[k] = computeField( dipole, dsParams.channel[i]);
						break;
					}
				}
			}
		}
	}
	else if ( gradient == 3 || gradient == 4 )
	{
		for (int k=0; k<dsParams.numG3Coefs; k++)
		{
			for (int i = 0; i < dsParams.numChannels; i++)
			{
				if ( dsParams.channel[i].isBalancingRef )
				{
					if ( !strncmp(dsParams.g3List[k], dsParams.channel[i].name, 5) )
					{
						if (computeMagnetic)
							referenceData[k] = computeFieldMagnetic( dipole, dsParams.channel[i], useDewar);
						else
							referenceData[k] = computeField( dipole, dsParams.channel[i]);
						break;
					}
				}
			}
		}
	}
	
	
	for (int i = 0; i < dsParams.numChannels; i++)
	{
		if ( dsParams.channel[i].isSensor || ( dsParams.channel[i].isBalancingRef && includeBalancingRefs ) )
		{
			// get field pattern for primary sensors
			if (computeMagnetic)
				dipPattern[sensorCount] = computeFieldMagnetic( dipole, dsParams.channel[i], useDewar);
			else
				dipPattern[sensorCount] = computeField( dipole, dsParams.channel[i]);

			// balance primary sensor data if not raw
			if ( dsParams.channel[i].isSensor && gradient > 0 )
			{
				double refData = 0.0;
				if ( gradient == 1 )
				{
					for (int k=0; k<dsParams.numG1Coefs; k++)
						refData += dsParams.channel[i].g1Coefs[k] * referenceData[k];
				}
				else if ( gradient == 2 )
				{
					for (int k=0; k<dsParams.numG2Coefs; k++)
						refData += dsParams.channel[i].g2Coefs[k] * referenceData[k];
				}
				else if ( gradient == 3 )
				{
					for (int k=0; k<dsParams.numG3Coefs; k++)
						refData += dsParams.channel[i].g3Coefs[k] * referenceData[k];
				}
				else if ( gradient == 4 )
				{
					for (int k=0; k<dsParams.numG4Coefs; k++)
						refData += dsParams.channel[i].g4Coefs[k] * referenceData[k];
				}
				
				dipPattern[sensorCount]	-= refData;
			}
			sensorCount++;
		}
	}
	
	return (true);
}

//  function to compute magnetic field due to a magnetic dipole for a single sensor channel
//
//  Magnetic field B(r)for a magnetic dipole with moment vector m at location r
//  where r = vector from dipole to point of measurement
//  and r0 is the unit vector r0 = r / |r| and mu0 = 4pi* 1e-7
//  B(r) = mu0/4pi * ( 3r(r0.m) - m / |r|^3 )
//
double computeFieldMagnetic( const dip_params & dipParams, const channelRec & channel, bool useDewar)
{
	vectorCart	coilLoc;
	vectorCart	qVec;
	vectorCart	pVec;
	vectorCart	r, r0;
	vectorCart	m;
	vectorCart	temp1, temp2, temp3, temp4, bfield;
	double 		field;
	double		mom;
	
	//  permeability coefficient mu0 = 4pi * 1e-7 weber/ amp-meter
	// 	since 4pi is in the denominator of equation it cancels out and therefore can be omitted here.
	double 		kMu = 1.0e-7;
	
	qVec.x = dipParams.xori;
	qVec.y = dipParams.yori;
	qVec.z = dipParams.zori;
	qVec = unitVector(qVec);                                // dipole orientation as unit vector
	
	mom = dipParams.moment * 1e-9;
	m = scaleVector(qVec, mom);                          // full moment vector m in nano-amp meters squared

	field = 0.0;
	for (int i=0; i<channel.numCoils; i++)
	{
		double coilField = 0.0;
		if ( i==0 )
		{
			// get vector r from dipole to point of measurement and convert to meters
			if (useDewar)
			{
				r.x = (channel.xpos_dewar - dipParams.xpos) * 0.01;
				r.y = (channel.ypos_dewar - dipParams.ypos) * 0.01;
				r.z = (channel.zpos_dewar - dipParams.zpos) * 0.01;
				pVec.x = channel.p1x_dewar;
				pVec.y = channel.p1y_dewar;
				pVec.z = channel.p1z_dewar;
			}
			else
			{
				r.x = (channel.xpos - dipParams.xpos) * 0.01;
				r.y = (channel.ypos - dipParams.ypos) * 0.01;
				r.z = (channel.zpos - dipParams.zpos) * 0.01;
				pVec.x = channel.p1x;
				pVec.y = channel.p1y;
				pVec.z = channel.p1z;
			}
		}
		else
		{
			if (useDewar)
			{
				r.x = (channel.xpos2_dewar - dipParams.xpos) * 0.01;
				r.y = (channel.ypos2_dewar - dipParams.ypos) * 0.01;
				r.z = (channel.zpos2_dewar - dipParams.zpos) * 0.01;
				pVec.x = channel.p2x_dewar;
				pVec.y = channel.p2y_dewar;
				pVec.z = channel.p2z_dewar;
			}
			else
			{
				r.x = (channel.xpos2 - dipParams.xpos) * 0.01;
				r.y = (channel.ypos2 - dipParams.ypos) * 0.01;
				r.z = (channel.zpos2 - dipParams.zpos) * 0.01;
				pVec.x = channel.p2x;
				pVec.y = channel.p2y;
				pVec.z = channel.p2z;
			}
		}
		
		pVec = unitVector(pVec); // make sure ...
		
		double lengthR = vectorLength( r );
		double r3 = lengthR * lengthR * lengthR;
		r0 = unitVector(r);						// r0 = r as unit vector
		double rdotM = vectorDotProduct(r0,m);  // r0 dot m
		
		temp1 = scaleVector(r0,3.0);			// 3r0
		temp2 = scaleVector(temp1, rdotM);		// 3r0(r0.m)
		temp3 = subtractVectors(temp2,m);		// 3r0(r0.m) - m
		temp4 = scaleVector(temp3, (1.0/r3) );	// 3r0(r0.m) - m / |r|^3
		bfield = scaleVector(temp4, kMu);		// mu0 * 3rhat(rhat.m) - m / |r|^3

		// Return gradiometer output as projection of B(r) onto coil direction vector (pVec)
		// The minus sign corrects for a flipped polarity of all pVecs as stored in the CTF headers.
		// The signOfGain corrects for the polarity of individual channel gains which are used to
		// standardize field direction (positive flux out) across all sensors in helmet.
		//
		double signOfGain = channel.properGain / fabs(channel.properGain);
		
		coilField = -(signOfGain) * vectorDotProduct( bfield, pVec );
		field += coilField;             // return gradiometer output as sum over coils
	}
	
	return(field);
}


/*
 Sarvas equations to compute forward solution (J. Sarvas, Phys. Med. Biol., 1987, 32: pp. 11-22) 
 for spherical model using CTF channel parameters and gains for a magnetometer or 1st order gradiometer
 written by D. Cheyne, 2005 
 */ 
double computeField( const dip_params & dipParams, const channelRec & channel )
{
	vectorCart	dipLoc;
	vectorCart	coilLoc;
	vectorCart	aVec;
	vectorCart	qVec;
	vectorCart	fieldVector;
	vectorCart	delF;
	vectorCart	delF1;
	vectorCart	delF2;
	vectorCart	QcrossR0;
	vectorCart	vec1;
	vectorCart	vec2;
	vectorCart	pVec;
	
	double 		field;
	double		F;
	double		a;
	double		r;
	double		temp1;
	double		temp2;
	double		temp3;
	double		num;
	double 		denom;
	double		mom;
	
	//  permeability coefficient mu0 = 4pi * 1e-7 weber/ amp-meter
	// 	since 4 pi is in the denominator of equation it cancels out and therefore can be omitted here.
	double 	kMu = 1.0e-7;
	
	// get dipole location vector (r0) in sphere coordinates and convert to meters
	dipLoc.x = (dipParams.xpos - channel.sphereX) * 0.01;
	dipLoc.y = (dipParams.ypos - channel.sphereY) * 0.01;
	dipLoc.z = (dipParams.zpos - channel.sphereZ) * 0.01;
	
	qVec.x = dipParams.xori;
	qVec.y = dipParams.yori;
	qVec.z = dipParams.zori;
	qVec = unitVector(qVec);                                // make sure...
	
	mom = dipParams.moment * 1e-9;                          // scale dipole magnitude to A-m
	qVec = scaleVector(qVec, mom);                          // full moment vector Q
	
	// *** previous assumption was that passed dipole orientation was always tangential to sphere
	// However, non-tangential dipoles can be passed to this routine. 
	// Since the term that goes into Sarvas equation is Q X r0  only the tangential component of 
	// the passed momemt vector will be used in either case so no check is necessary here.
	
	QcrossR0 = vectorCrossProduct( qVec, dipLoc );          // moved out of loop below since only need to compute this once!
	
  	field = 0.0;
	for (int i=0; i<channel.numCoils; i++)
	{
		double coilField = 0.0;
		if ( i==0 )
		{
			// translate to sphere coordinates and convert to meters
			coilLoc.x = (channel.xpos - channel.sphereX) * 0.01;	
			coilLoc.y = (channel.ypos - channel.sphereY) * 0.01;
			coilLoc.z = (channel.zpos - channel.sphereZ) * 0.01;
			pVec.x = channel.p1x;
			pVec.y = channel.p1y;
			pVec.z = channel.p1z;
		}
		else
		{
			coilLoc.x = (channel.xpos2 - channel.sphereX) * 0.01;
			coilLoc.y = (channel.ypos2 - channel.sphereY) * 0.01;
			coilLoc.z = (channel.zpos2 - channel.sphereZ) * 0.01;
			pVec.x = channel.p2x;
			pVec.y = channel.p2y;
			pVec.z = channel.p2z;
		}
		pVec = unitVector(pVec);
		
		//  a = r - r0
		aVec = subtractVectors( coilLoc, dipLoc );
		a = vectorLength( aVec );
		r = vectorLength( coilLoc );
		
		// compute scalar F
		temp1 = (r * a) + (r * r) - vectorDotProduct(dipLoc, coilLoc);
		F = a * temp1;
		
		// compute vector delF
		double adotr = vectorDotProduct(aVec, coilLoc);
		temp1 = ( (a * a)/r ) + ( adotr/a ) + (2.0 * a) + (2.0 * r);  		
		temp2 = a + (2.0*r) + ( adotr / a );
		delF1 = scaleVector(coilLoc, temp1);
		delF2 = scaleVector(dipLoc, temp2);
		delF = subtractVectors( delF1, delF2);
		
		num = kMu / ( F * F );
		
		// vec1 = compute F * (q X r)
	   	vec1 = scaleVector( QcrossR0, F);
		
		// vec2 =  (q X r) dot r times delF
		temp1 = vectorDotProduct( QcrossR0, coilLoc );
		vec2 = scaleVector( delF, temp1);
		
		fieldVector = subtractVectors( vec1, vec2 );
		fieldVector = scaleVector( fieldVector, num);
		
		double signOfGain = channel.properGain / fabs(channel.properGain);
		
		// Take projection onto coil axis direction and assign it a polarity equal to -(signOfGain)
		// The minus sign corrects for a flipped polarity of all pVecs as stored in the CTF headers.
		// The signOfGain corrects for the sign of individual channel gains which are used to
		// standardize field direction (positive flux out) across all sensors in helmet.
		//
		coilField = -(signOfGain) * vectorDotProduct( fieldVector, pVec );
		
		field += coilField;             // return gradiometer output if more than one coil
	}
	
	return (field);
}

// generic Simplex minimization
// takes any error function that returns error term
// termination is based on reaching tolerance (sum of improvement over 5 improvements < tolerance)
//
int runSimplexFit( int num_param,
				  double *param_array,
				  double *delta_array,
				  double (*ErrorFunction)(double *param_array),
				  int maximum_iter,
				  double tolerance)
{
	int         best, worst, iter_count, tol_counter, num_tol;
	double      sum, sum_improvement, oldError, newError;
	double      Terr, Rerr, Eerr, Cerr;
	double      best_old_error;
	double		start_error;
	double      *temp_param, *R_vertex, *E_vertex, *C_vertex, *ave, *error_vertex;
	double		*error_list;
	double      **vertex;

	// allocate memory to hold param arrays
	temp_param = (double *)malloc(num_param * sizeof(double) );
	if ( temp_param == NULL)
	{
		printf( "memory allocation failed for trialArray \n" );
		return(0);
	}
	R_vertex = (double *)malloc(num_param * sizeof(double) );
	if ( R_vertex == NULL)
	{
		printf( "memory allocation failed for R_vertex \n" );
		return(0);
	}
	E_vertex = (double *)malloc(num_param * sizeof(double) );
	if ( E_vertex == NULL)
	{
		printf( "memory allocation failed for E_vertex \n" );
		return(0);
	}
	C_vertex = (double *)malloc(num_param * sizeof(double) );
	if ( C_vertex == NULL)
	{
		printf( "memory allocation failed for C_vertex \n" );
		return(0);
	}
	ave = (double *)malloc(num_param * sizeof(double) );
	if ( ave == NULL)
	{
		printf( "memory allocation failed for ave \n" );
		return(0);
	}
	// error_vertex is n+1
	error_vertex = (double *)malloc( (num_param + 1) * sizeof(double) );
	if ( error_vertex == NULL)
	{
		printf( "memory allocation failed for error_vertex \n" );
		return(0);
	}
	
	// simplex is n+1 arrays of num_params
	vertex = (double **)malloc( (num_param + 1) * sizeof(double *) );
	if ( vertex == NULL)
	{
		printf( "memory allocation failed for vertex \n" );
		return(0);
	}
	for (int j = 0; j < (num_param + 1); j++)
	{
		vertex[j] = (double *)malloc( num_param * sizeof(double) );
		if ( vertex[j] == NULL)
		{
			printf( "memory allocation failed for vertex array\n" );
			return(0);
		}
	}
	
	error_list = (double *)malloc( maximum_iter * sizeof(double) );
	if ( error_list == NULL)
	{
		printf( "memory allocation failed for error_list \n" );
		return(0);
	}
	
	// initialize the vertex array -- delta values have been calculated elsewhere and passed
	// adds delta to one parameter at a time, except first vertex which is initial guess
	for (int k=0; k<num_param; k++)
	{
		for (int j=0; j<num_param+1; j++)
		{
			vertex[j][k] = param_array[k];
			vertex[k+1][k] = param_array[k] + delta_array[k];
		}
	}
	
	/* get initial error for each vertex */
	for (int k=0; k<num_param+1; k++)
		error_vertex[k] = ErrorFunction( vertex[k] );
	
	// ********* simplex loop ********
	
	tol_counter = 0;
	iter_count = 0;
	sum_improvement = 100000.0;
	num_tol = 5;	// this is somewhat arbitrary
	
	for (;;)
	{
		// resort to find best and worst vertices
		best = 0;
		worst = 0;
		for (int i=0; i<num_param+1; i++)
		{
			if (error_vertex[i] < error_vertex[best]) best = i;
			if (error_vertex[i] > error_vertex[worst]) worst = i;
		}
		
		if (iter_count == 0)
			best_old_error = ErrorFunction(vertex[best]);
		
		// simplex movement begins here
		// compute centroid for reflection etc
		for (int i=0; i<num_param; i++)
		{
			sum = 0;
			for (int j=0; j<num_param+1; j++)
			{
				if (j != worst)
					sum += vertex[j][i];
			}
			ave[i] = sum/(double)num_param;
		}
		
		// simplex movement begins here
		for (int i=0; i<num_param; i++)
			R_vertex[i] = ave[i] + (ave[i] - vertex[worst][i]); // reflect worst vertex
		Rerr = ErrorFunction(R_vertex);
		if (Rerr <= error_vertex[best] )
		{   // get expansion
			for (int i=0; i<num_param; i++)
				E_vertex[i] = R_vertex[i] + (R_vertex[i] - vertex[worst][i])/2;
			Eerr = ErrorFunction(E_vertex);
			if (Eerr > error_vertex[best])
			{    // take reflected
				for (int i=0; i<num_param; i++)
					vertex[worst][i] = R_vertex[i];
				error_vertex[worst] = Rerr;
			}
			else
			{   // take expanded
				for (int i=0; i<num_param; i++)
					vertex[worst][i] = E_vertex[i];
				error_vertex[worst] = Eerr;
			}
		}
		else if (Rerr > error_vertex[worst] )
		{    // do contraction
			for (int i=0; i<num_param; i++)
				C_vertex[i] = (ave[i] + vertex[worst][i]) /2.0;
			Cerr = ErrorFunction(C_vertex);
			if (Cerr <= error_vertex[worst])
			{  // take contracted
				for (int i=0; i<num_param; i++)
					vertex[worst][i] = C_vertex[i];
				error_vertex[worst] = Cerr;
			}
			else
			{   // contract all but best
				for (int i=0; i<num_param+1; i++)
				{
					if (i != best)
					{
						for (int j=0; j<num_param; j++)
						{
							vertex[i][j] = (vertex[i][j] + vertex[best][j]) /2;
							temp_param[j] = vertex[i][j];
						}
						Terr = ErrorFunction(temp_param);
						for (int j=0; j<num_param; j++)
							vertex[i][j] = temp_param[j];
						error_vertex[i] = Terr;
					}
				}
			}
		}
		else
		{   // take reflected
			for (int i=0; i<num_param; i++)
				vertex[worst][i] = R_vertex[i];
			error_vertex[worst] = Rerr;
		}
		
		newError = error_vertex[best];
		
		//  if improvement save best param's and update error
		if (newError < best_old_error)
		{
			// save current best params in param_array
			for (int i=0; i<num_param; i++)
				param_array[i] = vertex[best][i];
			error_list[tol_counter] = best_old_error - newError;
			best_old_error = newError;
			
			// terminate if the last num_tol improvments sum to a value less than tolerance
			if (tol_counter > num_tol)
			{
				sum_improvement = 0.0;
				for (int i=tol_counter; i>=tol_counter-num_tol; i--)
				{
					sum_improvement += error_list[i];
				}
			}
			tol_counter++;
			
			if (sum_improvement < tolerance)
				break;
		}
		
		// terminate if reached max. iterations allowed
		if (iter_count++ > maximum_iter)
		{
			for (int i=0; i<num_param; i++)
				param_array[i] = vertex[best][i];
			break;
		}
	}
	
	//	printf("Simplex terminated after %d iterations (final error = %.6f) ...\n", iter_count, best_old_error);
	
	free(ave);
	free(E_vertex);
	free(C_vertex);
	free(R_vertex);
	free(temp_param);
	for (int i=0; i<num_param+1; i++)
		free(vertex[i]);
	free(vertex);
	
	return ( iter_count-1 );
}
