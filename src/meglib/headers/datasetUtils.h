//  
// ***** new version for ctflib ******
// ***** see datasetUtils.cc for details ******** 
//

#ifndef DATASET_UTILS_H
#define DATASET_UTILS_H

#include "ByteSwap.h"
#include "fileUtils.h"
#include "vectorMath.h"
#include "CTF_DataHeaders.h"

#define	MAX_CHANNELS 450
#define CHANNEL_NAME_LENGTH 7		// assume anything beyond 7 characters is coeff versions number 

typedef struct channelRec
{
	char	name[32];
	int		index;
	int		sensorType;			// new - use to code different types of channels
	bool	isSensor;
	bool	isReference;		// new -  all reference channels
	bool	isBalancingRef;
	bool	isEEG;				// new - tag EEG channels since they have position info
	double	gain;				// combined gain qGain * properGain * ioGain
	double	properGain;
	double	qGain;
	double	ioGain;				// added for ADC channels
	int		numCoils;
	int		numTurns;
	double	coilArea;
	double	xpos;
	double	ypos;
	double	zpos;
	double	xpos2;
	double	ypos2;
	double	zpos2;
	double	p1x;
	double	p1y;
	double	p1z;
	double	p2x;
	double	p2y;
	double	p2z;
	int		gradient;
	double	g1Coefs[MAX_BALANCING];
	double	g2Coefs[MAX_BALANCING];
	double	g3Coefs[MAX_BALANCING];
	double	g4Coefs[MAX_BALANCING];
	double	sphereX;
	double 	sphereY;
	double	sphereZ;
	// added coilTbl locations for correct re-writing of .res4
	double	xpos_dewar;
	double	ypos_dewar;
	double	zpos_dewar;
	double	xpos2_dewar;
	double	ypos2_dewar;
	double	zpos2_dewar;
	double	p1x_dewar;
	double	p1y_dewar;
	double	p1z_dewar;
	double	p2x_dewar;
	double	p2y_dewar;
	double	p2z_dewar;	
} channelRec;

typedef struct ds_params 
{
	int			numSamples;
	int			numPreTrig;
	int			numChannels;
	int			numTrials;
	int			numSensors;				// new
	int			numReferences;			// new
	int			numBalancingRefs;		// new
	int			gradientOrder;			// new
	double		sampleRate;
	double		trialDuration;
	double		lowPass;
	double		highPass;
	double		epochMinTime;			// new
	double		epochMaxTime;			// new
	int	        numG1Coefs;
	int	        numG2Coefs;
	int	        numG3Coefs;
	int	        numG4Coefs;
	bool		hasBalancingCoefs;
	int			no_trials_avgd;		
	char		versionStr[256];		
	char		run_description[512];
	char		run_title[256];	
	char		operator_id[256];		
	char		g1List[MAX_BALANCING][32];
	char		g3List[MAX_BALANCING][32];
	channelRec	channel[MAX_CHANNELS];
} ds_params;


// Header for CTF .svl file format
typedef struct {
	int		Version;				// file version number
	char	SetName[256];		// name of parent dataset
	int		NumChans;				// number of channels used by SAM
	int		NumWeights;				// number of SAM virtual channels (0=static image)
	int		pad_bytes1;				// ** align next double on 8 byte boundary
	double	XStart;				// x-start coordinate (m)
	double	XEnd;				// x-end coordinate (m)
	double	YStart;				// y-start coordinate (m)
	double	YEnd;				// y-end coordinate (m)
	double	ZStart;				// z-start coordinate (m)
	double	ZEnd;				// z-end coordinate (m)
	double	StepSize;			// voxel step size (m)
	double	HPFreq;				// highpass frequency (Hz)
	double	LPFreq;				// lowpass frequency (Hz)
	double	BWFreq;				// bandwidth of filters (Hz)
	double	MeanNoise;			// mean primary sensor noise (T)
	char	MriName[256];			// MRI image file name
	int		Nasion[3];				// MRI voxel index for nasion
	int		RightPA[3];				// MRI voxel index for right pre-auricular
	int		LeftPA[3];				// MRI voxel index for left pre-auricular
	int		SAMType;				// SAM file type
	int		SAMUnit;				// SAM units (a bit redundant, but may be useful)
	int		pad_bytes2;				// ** align end of structure on 8 byte boundary
} SAM_HDR;

// added Aug 2021 - routines for reading and writing marker files.
#define	MAX_MARKER_SAMPLES 10000
#define	MAX_MARKERS 128

typedef struct markerStruct
{
	char	markerName[256];
	char	markerComment[256];
	char	markerColor[256];
	int		markerClassID;
	int		numSamples;
	int 	trial[MAX_MARKER_SAMPLES];
	double	latency[MAX_MARKER_SAMPLES];
} markerStruct;

typedef struct markerArray
{
	int				numMarkers;
	markerStruct	markers[MAX_MARKERS];
} markerArray;

// D. Cheyne - new logic for  res4 reading routines
// eliminated flags for sensors only and BAD channels
// always  read all info and use numSensors field instaed
double      getVersion();
int			getNumSensors( char *dsPath, bool includeReferences);
bool		copyDs( char *newName, char *oldName, bool includeData);
bool		readInfoDsFilters( char *dsName, double * highPass, double * lowPass);

bool		createDs( char *dsName, const ds_params & dsParams);
bool		writeMEGResFile(char *dsName, const ds_params & params);
bool		readMEGResFile(  char *resName, ds_params & dsParams);  

bool		readHeadCoilFile( char *fileName, vectorCart & na, vectorCart & le, vectorCart & re);
bool		writeHeadCoilFile( char *fileName, const vectorCart & na, const vectorCart & le, const vectorCart & re);

bool		writeGeomFile( char *fileName, const ds_params & params, bool sensorsOnly);
bool		readGeomFile( char *fileName, ds_params & params);

bool		createMEG4File( char *dsPath );
bool 		writeMEGTrialData( char *dsPath, const ds_params & dsParams, double **trialArray);

bool 		readMEGTrialData(char *dsPath, const ds_params & params, double **trialArray, int trialNo,	int gradientSelect, bool sensorsOnly);
bool 		readMEGChannelData(char *dsPath, const ds_params & params, char *channelName, double *chanArray, int trialNo, int gradientSelect);
bool 		readMEGDataAverage(char *dsName, ds_params & dsParams, double **megAve, int gradientSelect, bool sensorsOnly);
bool		printDsParams ( ds_params & dsParams, bool includeChannelRecs, bool includeCoeffs );

bool		saveVolumeAsSvl( char * svlFile, const vectorCart * voxelList,  
								double * imageData, 
								int numVoxels, 
								double xMin, 
								double xMax, 
								double yMin, 
								double yMax, 
								double zMin, 
								double zMax, 
								double stepSize,
								int imageType );

void swapSvlHeader( SAM_HDR * header, int format );

// D. Cheyne - new routines added Jan, 2014

void        getCTFHeadTransformation( vectorCart na, vectorCart le, vectorCart re, affine & tmat );
bool        updateSensorPositions( char * dsName, vectorCart na, vectorCart le, vectorCart re);


// D. Cheyne - added Aug, 2021
// need convenient way to check if we are dealing with multi-segment (large) datsets.
int 		getNumMEG4Segments( char *dsName );

// writeMEGTrialData always appends multipleTrials to one .meg4 file.
// Calling routines need to check that this will not exceed 2MB file limit, otherwise use this routine instead
bool 		writeMEGMultiSegTrialData( char *dsName, const ds_params & dsParams, double **trialArray, int trialNo );

// new routines to read and write MarkerFiles
bool 		readMarkerFile( char *dsName, markerArray & markerList);
bool 		writeMarkerFile( char *dsName, const markerArray & markerList);


#endif
