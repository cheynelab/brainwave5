#ifndef BW_UTILS_H
#define BW_UTILS_H

#include <pthread.h>
#include <stdlib.h>
#include <stdio.h>
// Nov 2025 moved code to common folder with ctflib ("meglib")
#include "../headers/sourceUtils.h"
#include "../headers/vectorMath.h"
#include "../headers/datasetUtils.h"
#include "../headers/fileUtils.h"
#include "../headers/BWFilter.h"
#include "../headers/path.h"    //File separator defined file, added by zhengkai

const double BWLIB_VERSION = 4.2;
const double DEF_VOL_XMIN = -10.0;
const double DEF_VOL_XMAX = 10.0;
const double DEF_VOL_YMIN = -8.0;
const double DEF_VOL_YMAX = 8.0;
const double DEF_VOL_ZMIN = 0.0;
const double DEF_VOL_ZMAX = 14.0;
const double DEF_VOL_STEP = 0.5;

#define	BF_TYPE_FIXED		0			// fixed orientation weights
#define	BF_TYPE_OPTIMIZED	1			// optimized orientation weights
#define	BF_TYPE_RMS			2			// RMS of vector weights
#define	BF_TYPE_VECTOR		3			// vector output

#define	BF_IMAGE_EVENT_RELATED	0			// event-related images
#define	BF_IMAGE_PSEUDO_Z		1			// single-state SAM
#define	BF_IMAGE_PSEUDO_T		2			// differential SAM (T)
#define	BF_IMAGE_PSEUDO_F		3			// differential SAM (F)
#define BF_IMAGE_CTF            4            // cross-talk function
#define BF_IMAGE_PSF            5            // point-spread function

// struct for beamformer parameters
typedef struct bf_params
{
	int			type;
	bool		normalized;
	bool		baselined;
	double		hiPass;
	double		lowPass;
	double		sphereX;
	double		sphereY;
	double		sphereZ;
	double		baselineWindowStart;
	double		baselineWindowEnd;
	double		noiseRMS;
} bf_params;

// static variable for multi-threaded weights routine

static char			*g_dsNamePtr;
static	ds_params	g_dsParams; 
static vectorCart	*g_voxelListPtr;
static vectorCart	*g_normalListPtr;
static double		**g_CovArray;
static double		**g_iCovArray;

static double		***g_wtsArrayPtr;
static double       ***g_fwdArrayPtr;

static double		**g_v1WeightsPtr;
static double		**g_v2WeightsPtr;

static int			g_numSensors;
static int			g_numWeightVectors;
static int			g_gradientOrder = -1; 

static bool			g_optimizeOrientation;
static double		g_sphereX = 0.0;
static double		g_sphereY = 0.0;
static double		g_sphereZ = 5.0;

// used for percent done only
static int			g_totVoxels;
static int			g_numVoxels;


#define NUM_WTS_THREADS 8
static pthread_t wtsThreads[NUM_WTS_THREADS];
static pthread_mutex_t wtsArrayMutex;

typedef struct 
{
	int threadID;
	int voxelStart;
	int voxelEnd;
} thread_wts_t;



//  static variables for multi-threaded covariance routine

static int				s_selectedGradient = -1;
static int				s_startSample;
static int				s_endSample;
static int				s_windowLength;
static int				s_totTrials = 0;
static ds_params		s_dsParams;

static double			**covArrayPtr;
static filter_params	*fparamsPtr;
static char				*dsNamePtr;

#define NUM_COV_THREADS 8

static pthread_t covThreads[NUM_COV_THREADS];
static pthread_mutex_t covArrayMutex;

typedef struct 
{
	int threadID;
	int trialStart;
	int trialEnd;
} thread_cov_t;

double  getBWLibVersion();

vectorCart		psi2cart( vectorCart dipLoc, double angle );

void			*wtsThread(void *threadArg);

bool            computeBeamformerWeights( char *dsName, ds_params & dsParams, double ***weight_array, int numWeightVectors, double **covArray,  double **icovArray,
								   vectorCart *voxelList, vectorCart *normalList, int numVoxels, bool optimizeOrientation);

bool			computeCovarianceMatrices(double **covArray, double **icovArray, int numSensors, char *dsName, filter_params & fparams, 
							   double wStart, double wEnd, double aStart, double aEnd, bool useAngleWindow, double regularization);

bool			computeVS(double **vsData, char *dsName, ds_params & dsParams, filter_params & fparams, bf_params & bparams, double **covArray, double **icovArray, 
						  double x, double y, double z, double *xo, double *yo, double *zo, bool computeSingleTrials);

bool			computeEventRelated(double **imageData, char *dsName, ds_params & dsParams, filter_params & fparams, bf_params & bparams, double **covArray, double **icovArray, int numVoxels, 
									vectorCart *voxelList, vectorCart *normalList, int numLatencies, double *latencyList, bool computePlusMinus, bool rectificationOff );

bool			computeDifferential(double **imageData, char *dsName, ds_params & dsParams, char * cdsName, bool useCovDs, filter_params & fparams, bf_params & bparams, double regularization,
						 int numVoxels, vectorCart *voxelList, vectorCart *normalList, double wStart, double wEnd, double bStart, double bEnd, int imageType );

bool			computeDifferentialMultiDs(double **imageData, char *dsName, ds_params & dsParams, char * cdsName, filter_params & fparams, bf_params & bparams, double regularization,
									int numVoxels, vectorCart *voxelList, vectorCart *normalList, double wStart, double wEnd, double bStart, double bEnd, int imageType );

// * added in 2025 - for CTF/PSF calculation need to return forward solutions corresponding to weights
void            *wtsThreadNew(void *threadArg);
bool            computeBeamformerWeightsNew( char *dsName, ds_params & dsParams, double ***forward_array, double ***weight_array, int numWeightVectors, double **covArray,
                                            double **icovArray, vectorCart *voxelList, vectorCart *normalList, int numVoxels, bool optimizeOrientation);
bool            computeCrossTalk(double **imageData, char *dsName, ds_params & dsParams, bf_params & bparams, double **covArray, double **icovArray,
                                    int numVoxels, vectorCart *voxelList, vectorCart *normalList, int voxel);

// moved here from datasetUtils.cc and computeCovariance.cc

void			*covThread(void *threadArg);
bool			getSensorCovariance ( char *dsName, double wStart, double wEnd, double **covArray, filter_params & fparams);

bool			getSensorDataAverage ( char *dsName, ds_params & params, double **megAve, filter_params & fparams);
bool			getSensorDataPlusMinusAverage ( char *dsName, ds_params & params, double **megAve, filter_params & fparams);
bool			getSensorData ( char *dsName, ds_params & params, double **megTrial,int trial, filter_params & fparams);



#endif
