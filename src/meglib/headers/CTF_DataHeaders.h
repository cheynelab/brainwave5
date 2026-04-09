#ifndef CTF_DATAHEADERS
#define CTF_DATAHEADERS

// - October 2010, D. Cheyne - updated res4 headers below to reflect ver 5.x CTF software	
//
// replaces MegDefs.h with int instead of long for 64 bit Linux
//

#define MAX_COILS			8							
#define SENSOR_LABEL		31
#define	MAX_AVERAGE_BINS	8
#define MAX_BALANCING		50

// SAM file types
#define SAM_TYPE_IMAGE		0		// flags file as a SAM static image file
#define SAM_TYPE_WT_ARRAY	1		// flags file as SAM coefficients for regular target array
#define SAM_TYPE_WT_LIST	2		// flags file as SAM coefficients for target list

// define SAM unit types
#define	SAM_UNIT_COEFF	0			// SAM coefficients A-m/T
#define	SAM_UNIT_MOMENT	1			// SAM source (or noise) strength A-m
#define	SAM_UNIT_POWER	2			// SAM source (or noise) power (A-m)^2
#define	SAM_UNIT_SPMZ	3			// SAM z-deviate
#define	SAM_UNIT_SPMF	4			// SAM F-statistic
#define	SAM_UNIT_SPMT	5			// SAM T-statistic
#define	SAM_UNIT_SPMP	6			// SAM probability
#define SAM_UNIT_MUSIC	7			// MUSIC metric

// Hex codes for gradient order in res4 file.
#define G1BR 0x47314252
#define G2BR 0x47324252
#define G3BR 0x47334252

#define G0AR 0x47304152
#define G1AR 0x47314152
#define G2AR 0x47324152
#define G3AR 0x47334152

#define G2OI 0x47324f49
#define G3OI 0x47334f49

const double CTFLIB_VERSION = 5.2;

typedef enum { CIRCULAR, SQUARE } CoilType_MEG4;  

typedef union d3_point_ext_MEG4
{
	struct	{ double x,y,z, junk ;} c;
	struct 	{ double r,theta,phi, junk ;} s;
	double 		point[4];
} d3_point_ext_MEG4;

typedef struct CoilRec_ext_MEG4
{  
	d3_point_ext_MEG4	position;
	d3_point_ext_MEG4	orient;
	short				numturns;
	// on the HP doubles are aligned on 8 byte boundaries 
	short				d1;
	short				d2;
	short				d3;
	double				area;
} CoilRec_ext_MEG4;

typedef struct
{			
	short				sensorTypeIndex;
	short				originalRunNum;
	CoilType_MEG4			coilShape;
	double				properGain;
	double				qGain;
	double				ioGain;
	double				ioOffset;
	short				numCoils;
	short				grad_order_no;
	int				stimPolarity;						// ** new (reassigned) in Ver 5
	CoilRec_ext_MEG4		coilTbl[MAX_COILS];
	CoilRec_ext_MEG4		HdcoilTbl[MAX_COILS];
} NewSensorResRec;

typedef struct
{
 	char 	nf_run_name[32],
			nf_run_title[256],
			nf_instruments[32],
			nf_collect_descriptor[32],
			nf_subject_id[32],
			nf_operator[32],
			nf_sensorFileName[60];
	int		size;
	
} meg4FileSetup;

typedef enum { CLASSERROR, BUTTERWORTH } classType;
typedef enum { TYPERROR, LOWPASS, HIGHPASS, NOTCH } filtType;

// added for writing res file -- 
typedef enum { eMEGReference,
	eMEGReference1,
	eMEGReference2,
	eMEGReference3,
	eMEGSensor,
	eMEGSensor1,
	eMEGSensor2,
	eMEGSensor3,
	eEEGRef,
	eEEGSensor,
	eADCRef,
	eStimRef,
	eTimeRef,
	ePositionRef,
	eDACRef,
	eSAMSensor,  //  added new types for vers 5  - D. Cheyne Oct, 2010
	eVirtualSensor,
	eSystemTimeRef,
	eADCVoltRef,
	eStimAnalog,
	eStimDigital,
	eEEGBipolar,
	eEEGAflg,
	eMEGReset,
	eDipSrc,
	eSAMSensorNorm,
	eAngleRef,
	eExtractionRef,
	eFitErr,
	eOtherRef,
	eInvalidType
} SensorType;

// following not use for reading filters - doesn't work...
typedef struct
{
		double		freq;
		classType	fClass;
		filtType	fType;
		short		numParam;
		short		d1;
		double		*params;
} filter;

typedef struct 
{
		int			no_samples;
		short			no_channels;
		short			d1;
		double			sample_rate;
		double			epoch_time;
		short			no_trials;
		short			d2;
		int			preTrigPts;
		short			no_trials_done;
		short			no_trials_display;
		int			save_trials;
		unsigned char		primaryTrigger;
		unsigned char		secondaryTrigger[MAX_AVERAGE_BINS];
		unsigned char		triggerPolarityMask;
		unsigned char		d3;
		unsigned char		d4;
		short			trigger_mode;
		unsigned char		d5;
		int			accept_reject_Flag;
		short			run_time_display;
		short			d6;
		int			zero_Head_Flag;
		int			artifact_mode;
} new_general_setup_rec_ext;

typedef struct
{
	char						appName[256];
	char						dataOrigin[256];
	char						dataDescription[256];
	short						no_trials_avgd;
	char						data_time[255];	        
	char						data_date[255];	        
	new_general_setup_rec_ext	gSetUp;
	meg4FileSetup				nfSetUp;
} meg4GeneralResRec;

typedef struct CoefResRec4
{		
	short			num_of_coefs;
	char			sensor_list[MAX_BALANCING][SENSOR_LABEL];	
	double			coefs_list[MAX_BALANCING];	
} CoefResRec4;

typedef struct 
{
	char			sensorName[32];
	unsigned int	coefType;
	int				d1;  		// pad out to the next 8 byte boundary €€€
	CoefResRec4		coefRec;
} SensorCoefResRec;

#endif
