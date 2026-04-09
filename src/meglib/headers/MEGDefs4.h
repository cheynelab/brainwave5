#define MAX_COILS		8							
#define SENSOR_LABEL		31
#define	MAX_AVERAGE_BINS	8
#define MAX_BALANCING		50

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
	short			numturns;
	// on the HP doubles are aligned on 8 byte boundaries €€€
	short			d1;
	short			d2;
	short			d3;
	double			area;
} CoilRec_ext_MEG4;

typedef struct
{			
	short  		sensorTypeIndex;
	short		originalRunNum;
	CoilType_MEG4	coilShape;
	double		properGain;
	double		qGain;
	double		ioGain;
	double		ioOffset;
	short		numCoils;
	short 		grad_order_no;
	long		d1;		//€€€ 4 bytes of padding out to an 8 byte boundary €€€
	CoilRec_ext_MEG4	coilTbl[MAX_COILS];
	CoilRec_ext_MEG4	HdcoilTbl[MAX_COILS];
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
	long	size;
	
} meg4FileSetup;

typedef enum { CLASSERROR, BUTTERWORTH } classType;
typedef enum { TYPERROR, LOWPASS, HIGHPASS, NOTCH } filtType;

typedef struct
{
		double freq;
		classType fClass;
		filtType fType;
		short numParam;
		short d1;
		double *params;
} filter;

typedef struct 
{
		long no_samples;
		short no_channels;
		short d1;
		double sample_rate;
		double epoch_time;
		short no_trials;
		short d2;
		long preTrigPts;
		short no_trials_done;
		short no_trials_display;
		long save_trials;
		unsigned char primaryTrigger;
		unsigned char secondaryTrigger[MAX_AVERAGE_BINS];
		unsigned char triggerPolarityMask;
		unsigned char	d3;
		unsigned char	d4;
		short trigger_mode;
		unsigned char	d5;
		long accept_reject_Flag;
		short run_time_display;
		short	d6;
		long zero_Head_Flag;
		long artifact_mode;
} new_general_setup_rec_ext;

typedef struct
{
	char				appName[256];
	char				dataOrigin[256];
	char				dataDescription[256];
	short				no_trials_avgd;
	char  				data_time[255];	        
	char  				data_date[255];	        
	new_general_setup_rec_ext	gSetUp;
	meg4FileSetup			nfSetUp;
} meg4GeneralResRec;

typedef struct CoefResRec4
{		
	short			num_of_coefs;
	char			sensor_list[MAX_BALANCING][SENSOR_LABEL];	
	double			coefs_list[MAX_BALANCING];	
} CoefResRec4;

typedef struct 
{
	char		sensorName[32];
	unsigned long	coefType;
	long		d1;  		// pad out to the next 8 byte boundary €€€
	CoefResRec4	coefRec;
} SensorCoefResRec;


