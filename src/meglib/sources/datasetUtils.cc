///////////////////////////////////////////////////////////
//
// datasetUtils.cc
// New version for ctflib  
//
//		(c) Douglas O. Cheyne, 2012  All rights reserved.
// 
// Revisions:
//				May 11, 2012	- new version based on the old MEGlib code
//								- moved forward solution routines to here for doing simulations etc...
//								- moved GetSensorDataAverage etc to bwUtils.  This eliminates dependency on BWFilter
// 
// 
//				Aug, 2021		- changes to handle multi-segment data.
//              June, 2025              - recompiled for brainwave5

 
#include <limits.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <sys/stat.h>
#if defined _WIN64 || defined _WIN32
    #include <unistd.h>
#endif
#include <time.h>

///////

#include "../headers/BWFilter.h"  
#include "../headers/CTF_DataHeaders.h"    // replaces MEGDefs4.h with long definitions that create problems on 64 bit Linux!

#include "../headers/datasetUtils.h"
#include "../headers/path.h"				//File separator definition file, adde by zhengkai


double 		**DS_trialArray;
ds_params       DS_dsParams;                // BW Vers 3.3 - moved out of routines to avoid stack overflow (D. Cheyne)

// need dummy return values for all functions to avoid compiler warnings.
int     errCode;
int     bytesRead;
size_t  dataSize;
char *  charPtr;

double  getVersion()
{
    
    return(CTFLIB_VERSION);
}    // unused var change to force git update....



bool copyDs( char *oldDsName, char *newDsName, bool includeData)
{
	char 	cmd[2048];
	char	dsBaseName[256];
	char	newDsBaseName[256];

	FILE 	*fp;
	
	fp = fopen(newDsName, "r");
	if ( fp != NULL)
	{
		printf("copyDs cannot overwrite existing dataset %s\n", newDsName);
		fclose(fp);
		return (false);
	}

	printf("creating dataset %s...\n", newDsName );

	
#if _WIN32||WIN64
	if ( mkdir(newDsName ) == -1 ) //modified for mingw, added by zhengkai
	{
		printf("Could not create directory %s, check file permissions \n", newDsName);
		return (false);
	}
#else
	if ( mkdir(newDsName, S_IRUSR | S_IWUSR | S_IXUSR ) == -1 )	
	{
		printf("Could not create directory %s, check file permissions \n", newDsName);
		return (false);
	}
#endif
 
	removeFilePath( oldDsName, dsBaseName);
	dsBaseName[strlen(dsBaseName)-3] = '\0';
	
	removeFilePath( newDsName, newDsBaseName);
	newDsBaseName[strlen(newDsBaseName)-3] = '\0';

	// copy resource file
	sprintf(cmd, "cp %s%s%s.res4 %s%s%s.res4", oldDsName, FILE_SEPARATOR, dsBaseName, newDsName, FILE_SEPARATOR, newDsBaseName );
	//printf("executing %s\n", cmd);
	errCode = system(cmd);	


	if ( includeData )
	{
		// copy resource file
		sprintf(cmd, "cp %s%s%s.meg4 %s%s%s.meg4", oldDsName, FILE_SEPARATOR, dsBaseName, newDsName, FILE_SEPARATOR, newDsBaseName );
		//printf("executing %s\n", cmd);
		errCode = system(cmd);	
	}

	// copy head coil file
	sprintf(cmd, "cp %s%s%s.hc %s%s%s.hc", oldDsName, FILE_SEPARATOR, dsBaseName, newDsName, FILE_SEPARATOR, newDsBaseName );
	//printf("executing %s\n", cmd);
	errCode = system(cmd);	

	// copy marker file
	sprintf(cmd, "cp %s%sMarkerFile.mrk %s%sMarkerFile.mrk", oldDsName, FILE_SEPARATOR, newDsName, FILE_SEPARATOR);
	//printf("executing %s\n", cmd);
	errCode = system(cmd);	

	// copy Badchannels file
	sprintf(cmd, "cp %s%sBadChannels %s%sBadChannels", oldDsName,FILE_SEPARATOR, newDsName, FILE_SEPARATOR);
	//printf("executing %s\n", cmd);
	errCode = system(cmd);	

	// copy processing file
	sprintf(cmd, "cp %s%sprocessing.cfg %s%sprocessing.cfg", oldDsName, FILE_SEPARATOR, newDsName, FILE_SEPARATOR);
	//printf("executing %s\n", cmd);
	errCode = system(cmd);		      


	return (true);
	
}

bool createMEG4File( char *dsName )
{
	char		meg4Name[256];
	char		dsBaseName[64];
	char		dsHeaderString[8];
	FILE		*fp;
	double		d1;

	
	removeFilePath( dsName, dsBaseName);
	dsBaseName[strlen(dsBaseName)-3] = '\0';
	sprintf(meg4Name, "%s%s%s.meg4", dsName, FILE_SEPARATOR, dsBaseName );

	if ( ( fp = fopen( meg4Name, "wb") ) == NULL )
	{
		printf("Couldn't create.meg4 file %s\n", meg4Name );
		return(false);
	}

	// write 8 byte header
	sprintf(dsHeaderString, "MEG41CP");
	fwrite(dsHeaderString, sizeof( char ), 8, fp );
	

	fclose( fp );

	return (true);

}

bool writeMEGTrialData( char *dsName, const ds_params & dsParams, double **trialArray )
{
	char		meg4Name[256];
	char		dsBaseName[64];
	char		dsHeaderString[8];
	FILE		*fp;
	double		d1;
	int			*trialBuffer;
    long int    pointsPerTrial;
    
	if ( trialArray == NULL )
	{
		printf("Null pointer passed to writeMEGData...\n");
		return (false);
	}
	
	removeFilePath( dsName, dsBaseName);
	dsBaseName[strlen(dsBaseName)-3] = '\0';
	sprintf(meg4Name, "%s%s%s.meg4", dsName, FILE_SEPARATOR, dsBaseName );
	
	pointsPerTrial = dsParams.numChannels * dsParams.numSamples;
	
	trialBuffer = (int *)malloc( sizeof(int) * pointsPerTrial);
	
	if ( trialBuffer == NULL)
	{
		printf("memory allocation failed for trial buffer\n");
		return(false);
	}
	
	if ( ( fp = fopen( meg4Name, "ab") ) == NULL )
	{
		printf("Couldn't open .meg4 file %s for appending \n", meg4Name );
		return(false);
	}
	
	int sampleCount = 0;
	
	for (int j=0; j<dsParams.numChannels; j++) 
	{					
		double thisGain =  dsParams.channel[j].gain;		
		
		for (int k=0; k<dsParams.numSamples; k++ )
		{
			d1 = trialArray[j][k] * thisGain;			// convert to integer data
			int iVal =  (int)d1;						// truncate fractional part
			trialBuffer[sampleCount++] = ToFile(iVal);	// put in one-dim. long array for write	
		}
	}	
	
	fwrite( trialBuffer, sizeof(int), pointsPerTrial, fp);
	
	fclose( fp );
	
	free( trialBuffer );
	
	return (true);
	
}
// added Sept, 2021
// writeMEGTrialData always appends multipleTrials to one .meg4 file.
// Calling routines need to check that this will not exceed 2MB file limit, and if so use this routine instead

bool writeMEGMultiSegTrialData( char *dsName, const ds_params & dsParams, double **trialArray, int trialNo )
{
	char		meg4Name[256];
	char		dsBaseName[64];
	char		dsHeaderString[8];
	FILE		*fp;
	double		d1;
	int			*trialBuffer;

	if ( trialArray == NULL )
	{
		printf("Null pointer passed to writeMEGData...\n");
		return (false);
	}
	
	removeFilePath( dsName, dsBaseName);
	dsBaseName[strlen(dsBaseName)-3] = '\0';
	
	if (trialNo == 0)
		sprintf(meg4Name, "%s%s%s.meg4", dsName, FILE_SEPARATOR, dsBaseName );
	else
		sprintf(meg4Name, "%s%s%s.%d_meg4", dsName, FILE_SEPARATOR, dsBaseName, trialNo );
	
	int pointsPerTrial = dsParams.numChannels * dsParams.numSamples;
	
	trialBuffer = (int *)malloc( sizeof(int) * pointsPerTrial);
	
	if ( trialBuffer == NULL)
	{
		printf("memory allocation failed for trial buffer\n");
		return(false);
	}
	
	if ( ( fp = fopen( meg4Name, "wb") ) == NULL )
	{
		printf("Couldn't open .meg4 file %s for writing \n", meg4Name );
		return(false);
	}
	
	// write 8 byte header - this should just overwrite header if .meg4 already created with CreateMeg4File
	
	sprintf(dsHeaderString, "MEG41CP");
	fwrite(dsHeaderString, sizeof( char ), 8, fp );
	
	int sampleCount = 0;
	
	for (int j=0; j<dsParams.numChannels; j++)
	{
		double thisGain =  dsParams.channel[j].gain;
		
		for (int k=0; k<dsParams.numSamples; k++ )
		{
			d1 = trialArray[j][k] * thisGain;			// convert to integer data
			int iVal =  (int)d1;						// truncate fractional part
			trialBuffer[sampleCount++] = ToFile(iVal);	// put in one-dim. long array for write
		}
	}
	
	fwrite( trialBuffer, sizeof(int), (int)pointsPerTrial, fp);
	
	fclose( fp );
	
	free( trialBuffer );
	
	return (true);
	
}



///////////////////////////////////////////////////////////////////////////////////////////////
//  D. Cheyne Oct 2010 
//		- new routines for generating datasets from scratch to replace above routines
//      - allows parameters to be changed etc..
///////////////////////////////////////////////////////////////////////////////////////////////

bool createDs( char *dsName, const ds_params & dsParams)
{
	char 	cmd[256];
	
	FILE 	*fp;
	
	fp = fopen(dsName, "r");
	if ( fp != NULL)
	{
		printf("createDs cannot overwrite existing dataset %s\n", dsName);
		fclose(fp);
		return (false);
	}
	
	printf("creating new dataset %s...\n", dsName );

#if _WIN32||WIN64
	if ( mkdir(dsName) == -1 )//modified for mingw, added by zhengkai
	{
		printf("Could not create directory %s, check file permissions \n", dsName);
		return (false);
	}
#else
	if ( mkdir(dsName, S_IRUSR | S_IWUSR | S_IXUSR ) == -1 )	
	{
		printf("Could not create directory %s, check file permissions \n", dsName);
		return (false);
	}
#endif
 

	
	// make sure file mode is correct...
	sprintf(cmd,"chmod a+rX %s",dsName);
	int errCode = system(cmd);
	
	writeMEGResFile(dsName, dsParams);
	
	return (true);
	
}

// D. Cheyne, Oct, 2010
// now writes all information ...
// Assumes directory has already been created by createDs

// D. Cheyne June, 2014 - set text fields to have some default values rather than leaving blank

bool writeMEGResFile(char *dsName, const ds_params & params)
{
	// Declare variables.
	char				resName[256];
	char				baseName[64];

	meg4GeneralResRec	grr4;
	NewSensorResRec		*sensorRes4;	
	SensorCoefResRec	sensorCoef;  // only need one 
	
	FILE				*fp;
	
	short				numFilters;
	double				fFrequency;
	int					fType;
	short				sensorTypeIndex;
	int					gradient;
	double				coilArea;

	char				IDString[256] = "MEG42RS";
	char				tstr[256];
	int					unused = 0; // padding
	
	char				runDescription[256];
	int					runDescLength;
	
	removeFilePath( dsName, baseName);
	baseName[strlen(baseName)-3] = '\0';
	sprintf(resName, "%s%s%s.res4", dsName,FILE_SEPARATOR, baseName );	
	
	sensorRes4 = ( NewSensorResRec *)malloc( params.numChannels * sizeof( NewSensorResRec ) );
	if ( sensorRes4 == NULL ) 
	{
		printf("Error allocating memory for sensor record\n");
		return( false);
	}

	// Put general dataset information in meg4GeneralResRec structure type and swap bytes for writing.
	grr4.gSetUp.no_samples = ToFile(params.numSamples);
	grr4.gSetUp.no_channels = ToFile((short)params.numChannels);
	grr4.gSetUp.sample_rate = ToFile(params.sampleRate);
	
	// make sure epoch time is correct
	double trialDuration = params.numSamples * (1.0 / params.sampleRate);
	grr4.gSetUp.epoch_time = ToFile(trialDuration * params.numTrials);
	grr4.gSetUp.no_trials = ToFile((short)params.numTrials);
	grr4.gSetUp.preTrigPts = ToFile(params.numPreTrig);

	// some additional stuff only needed for re-writing .meg4 files...
	strncpy( grr4.nfSetUp.nf_run_name, baseName,32 );
	strcpy( grr4.nfSetUp.nf_run_title,"uknown\n");
	
	strcpy( grr4.nfSetUp.nf_operator,"uknown\n");
	strcpy( grr4.nfSetUp.nf_collect_descriptor,"\n");

	grr4.no_trials_avgd = ToFile((short)params.no_trials_avgd);	
	time_t	CurrentDateTime = time(NULL);
	strftime (grr4.data_time, 255, "%X", localtime(&CurrentDateTime));
	strftime (grr4.data_date, 255, "%d/%m/%Y", localtime(&CurrentDateTime));

	// ** important - header size depends on length of this string which is stored in nfSetup.size  **
	sprintf(runDescription,"%s\n","none");
	runDescLength = strlen(runDescription);
	grr4.nfSetUp.size = ToFile(runDescLength);	
	
	// except for trigger info it is not clear these are ever set or used - apply default values for now...
	strcpy( grr4.nfSetUp.nf_instruments, "unknown\n" );
	strcpy( grr4.nfSetUp.nf_subject_id, "unknown\n" );
	strcpy( grr4.nfSetUp.nf_sensorFileName, "unknown\n" );
	strcpy( grr4.dataDescription, "unknown\n");
	grr4.gSetUp.no_trials_done = ToFile((short)0);
	grr4.gSetUp.no_trials_display = ToFile((short)0);
	grr4.gSetUp.save_trials = ToFile((int)0);
	grr4.gSetUp.primaryTrigger = (unsigned char)0;
	grr4.gSetUp.triggerPolarityMask = (unsigned char)0;
	grr4.gSetUp.trigger_mode = ToFile((short)0);
	grr4.gSetUp.accept_reject_Flag = ToFile((int)0);
	grr4.gSetUp.run_time_display = ToFile((short)0);
	grr4.gSetUp.zero_Head_Flag = ToFile((int)0);
	grr4.gSetUp.artifact_mode = ToFile((int)0);
	strcpy( grr4.appName, "megcode" );
	strcpy( grr4.dataOrigin, "unknown" );
	
	// Put sensors in NewSensorResRec structure type.
	sensorRes4 = ( NewSensorResRec *)malloc( params.numChannels * sizeof( NewSensorResRec ) );
	if ( sensorRes4 == NULL ) 
	{
		printf("Error allocating memory for sensor record\n");
		return(false);
	}
	
	for (int i = 0; i < params.numChannels; i++) 
	{
		// Add what is not in params.
		sensorRes4[i].originalRunNum = ToFile((short)0);
		sensorRes4[i].coilShape = CIRCULAR; // This is zero, so byte swapping does nothing.  However, get error when using ToFile.
		sensorRes4[i].ioOffset = ToFile((double)0);
		
		sensorRes4[i].sensorTypeIndex = ToFile((short)params.channel[i].sensorType);
		
		sensorRes4[i].numCoils = ToFile((short)params.channel[i].numCoils);
		sensorRes4[i].properGain = ToFile(params.channel[i].properGain);
		sensorRes4[i].qGain = ToFile(params.channel[i].qGain);
		sensorRes4[i].ioGain = ToFile(params.channel[i].ioGain);		// added field to struct Aug, 2020.
		gradient = params.channel[i].gradient;
		if (gradient == 4)
			gradient = 13;
		sensorRes4[i].grad_order_no = ToFile((short)gradient);
		
		// head coordinates
		sensorRes4[i].HdcoilTbl[0].numturns = ToFile((short)params.channel[i].numTurns);
		sensorRes4[i].HdcoilTbl[0].area = ToFile( params.channel[i].coilArea) ;
		sensorRes4[i].HdcoilTbl[0].position.c.x = ToFile(params.channel[i].xpos);
		sensorRes4[i].HdcoilTbl[0].position.c.y = ToFile(params.channel[i].ypos);
		sensorRes4[i].HdcoilTbl[0].position.c.z = ToFile(params.channel[i].zpos);
		sensorRes4[i].HdcoilTbl[0].orient.c.x = ToFile(params.channel[i].p1x);
		sensorRes4[i].HdcoilTbl[0].orient.c.y = ToFile(params.channel[i].p1y);
		sensorRes4[i].HdcoilTbl[0].orient.c.z = ToFile(params.channel[i].p1z);
		if ( params.channel[i].numCoils > 1 ) 
		{
			sensorRes4[i].HdcoilTbl[1].numturns = ToFile((short)params.channel[i].numTurns);
			sensorRes4[i].HdcoilTbl[1].area = ToFile( params.channel[i].coilArea) ;
			sensorRes4[i].HdcoilTbl[1].position.c.x = ToFile(params.channel[i].xpos2);
			sensorRes4[i].HdcoilTbl[1].position.c.y = ToFile(params.channel[i].ypos2);
			sensorRes4[i].HdcoilTbl[1].position.c.z = ToFile(params.channel[i].zpos2);
			sensorRes4[i].HdcoilTbl[1].orient.c.x =ToFile(params.channel[i].p2x);
			sensorRes4[i].HdcoilTbl[1].orient.c.y =ToFile(params.channel[i].p2y);
			sensorRes4[i].HdcoilTbl[1].orient.c.z =ToFile(params.channel[i].p2z);
		}
		
		// dewar coordinates
		sensorRes4[i].coilTbl[0].area = ToFile( params.channel[i].coilArea) ;
		sensorRes4[i].coilTbl[0].numturns = ToFile((short)params.channel[i].numTurns);
		sensorRes4[i].coilTbl[0].position.c.x = ToFile(params.channel[i].xpos_dewar);
		sensorRes4[i].coilTbl[0].position.c.y = ToFile(params.channel[i].ypos_dewar);
		sensorRes4[i].coilTbl[0].position.c.z = ToFile(params.channel[i].zpos_dewar);
		sensorRes4[i].coilTbl[0].orient.c.x = ToFile(params.channel[i].p1x_dewar);
		sensorRes4[i].coilTbl[0].orient.c.y = ToFile(params.channel[i].p1y_dewar);
		sensorRes4[i].coilTbl[0].orient.c.z = ToFile(params.channel[i].p1z_dewar);
		if ( params.channel[i].numCoils > 1 ) 
		{
			sensorRes4[i].coilTbl[1].numturns = ToFile((short)params.channel[i].numTurns);
			sensorRes4[i].coilTbl[1].area = ToFile( params.channel[i].coilArea) ;
			sensorRes4[i].coilTbl[1].position.c.x = ToFile(params.channel[i].xpos2_dewar);
			sensorRes4[i].coilTbl[1].position.c.y = ToFile(params.channel[i].ypos2_dewar);
			sensorRes4[i].coilTbl[1].position.c.z = ToFile(params.channel[i].zpos2_dewar);
			sensorRes4[i].coilTbl[1].orient.c.x =ToFile(params.channel[i].p2x_dewar);
			sensorRes4[i].coilTbl[1].orient.c.y =ToFile(params.channel[i].p2y_dewar);
			sensorRes4[i].coilTbl[1].orient.c.z =ToFile(params.channel[i].p2z_dewar);
		}
	}

	
	// write a .meg4  file
	if ( ( fp = fopen( resName, "wb") ) == NULL ) 
	{
		printf("couldn't open [%s]\n", resName);
		return(false);
	}
	
	// 1.  header
	sprintf(IDString, "%s", params.versionStr);
	printf("writing version %s .res4 file...\n", params.versionStr);
	fwrite( IDString, sizeof( char ), 8, fp );
	
	// 2. general resource struct
	fwrite( & grr4, sizeof( meg4GeneralResRec ), 1, fp );
	
	// 3. unused 4 bytes padding  
	fwrite( & unused, sizeof(unsigned char), 4, fp ); 
	//fwrite( & unused, sizeof(int), 1, fp );
	
	// 4. run description - variable length !! is determined above
	//printf("writing runDescription %d <%s> \n",runDescLength,runDescription );
	fwrite( runDescription, sizeof( char ), runDescLength, fp );
	
	// 5. filtering information - variable length
	int	fClass = ToFile((int)1);	// some dummy params - just need cutoffs...
	short fNumParams = ToFile((short)0);
	if ( params.highPass == 0 ) 
	{ // skip high pass
		numFilters = ToFile((short)1);
		fwrite( & numFilters, sizeof( short ), 1, fp );
	}
	else 
	{ // include high pass
		numFilters = ToFile((short)2);
		fwrite( & numFilters, sizeof( short ), 1, fp );
		
		fFrequency = ToFile(params.highPass);
		fwrite(& fFrequency, sizeof(double), 1, fp);
		fwrite(& fClass, sizeof(int), 1, fp);
		fType = ToFile(HIGHPASS);
		fwrite(& fType, sizeof(int), 1, fp);
		fwrite(& fNumParams, sizeof(short), 1, fp);
	}
	
	fFrequency = ToFile(params.lowPass);
	fwrite(& fFrequency, sizeof(double), 1, fp);
	fwrite(& fClass, sizeof(int), 1, fp);
	fType = ToFile(LOWPASS);
	fwrite(& fType, sizeof(int), 1, fp);
	fwrite(& fNumParams, sizeof(short), 1, fp);
	
	
	// 6. write channel names as contiguous block of 32 character array
	char nameStr[32];
	for (int i=0; i<params.numChannels ; i++) 
	{
		strncpy(nameStr,params.channel[i].name,31);
		fwrite( nameStr, sizeof(char), 32, fp );
	}
	
	// 7. sensor resources - gains, positions etc...
	fwrite( sensorRes4, sizeof(NewSensorResRec), params.numChannels, fp );

	// 8. write out balancing coefficient records -- see notes in readMEGResFile
	
	// need to figure out how many gradients we are going to write 
	int n_grads = 0;
	if (params.numG1Coefs > 0) n_grads++;
	if (params.numG2Coefs > 0) n_grads++;
	if (params.numG3Coefs > 0) n_grads++;
	if (params.numG4Coefs > 0) n_grads++;
	
	if (n_grads == 0 || !params.hasBalancingCoefs)
	{
		short swappednCoeffs = ToFile(0);
		fwrite( & swappednCoeffs, sizeof(short), 1, fp );
	}
	else
	{
		short nCoeffs = (n_grads * params.numSensors) + params.numReferences;
		short swappednCoeffs = ToFile(nCoeffs);
		fwrite( & swappednCoeffs, sizeof(short), 1, fp );
			
		char	refList[MAX_BALANCING][256];
		double	coeffList[MAX_BALANCING];
		
		for (int i=0; i<params.numChannels; i++) 
		{
			if (params.channel[i].isReference)
			{
				// for references need to write G1 coeffs only
				sensorCoef.coefType = ToFile(G1BR);
				sensorCoef.coefRec.num_of_coefs = ToFile( (short)params.numG1Coefs );
				strncpy(sensorCoef.sensorName, params.channel[i].name,32);
							
				// convert coefficients back to phiOs
				for (int j=0;j<params.numG1Coefs;j++) 
				{
					strncpy(sensorCoef.coefRec.sensor_list[j], params.g1List[j], 32);
					double coeff = params.channel[i].g1Coefs[j];
				
					// have to undo multiplication by ratio of gains...
					for (int k=0; k< params.numChannels;k++)
					{
						if ( !strncmp( params.channel[k].name, params.g1List[j], 5) ) 
						{
							// must multiply coefficient by ratio of refGain / sensorGain if applying to data in Tesla
							coeff *= params.channel[i].properGain / params.channel[k].properGain;
							break;
						}
					}
					sensorCoef.coefRec.coefs_list[j] = ToFile(coeff);
				}			
				fwrite( & sensorCoef, sizeof(SensorCoefResRec), 1, fp );
			}
			else if (params.channel[i].isSensor)
			{
				// for sensors write 4 records - in reverse order same as CTF software (but shouldn't matter)
				// 3rd + adaptive
				int		numCoeffs;
				
				for (int gradType = 0; gradType < 4; gradType++)
				{
					if (gradType == 0)		// 3rd+adaptive , uses G3 list
					{
						numCoeffs = params.numG4Coefs;
						sensorCoef.coefType = ToFile(G3AR);
						for (int j=0;j<numCoeffs;j++) 
						{
							sprintf(refList[j],"%s",params.g3List[j]);
							coeffList[j] = params.channel[i].g4Coefs[j];
						}
					}
					else if (gradType == 1) // 3rd order
					{
						numCoeffs = params.numG3Coefs;
						sensorCoef.coefType = ToFile(G3BR);
						for (int j=0;j<numCoeffs;j++) 
						{
							sprintf(refList[j],"%s",params.g3List[j]);
							coeffList[j] = params.channel[i].g3Coefs[j];
						}					
					}
					else if (gradType == 2) // 2nd order, uses G1 list
					{
						numCoeffs = params.numG2Coefs;
						sensorCoef.coefType = ToFile(G2BR);
						for (int j=0;j<numCoeffs;j++) 
						{
							sprintf(refList[j],"%s",params.g1List[j]);
							coeffList[j] = params.channel[i].g2Coefs[j];
						}					
					}
					else if (gradType == 3) // 1st order
					{
						numCoeffs = params.numG1Coefs;
						sensorCoef.coefType = ToFile(G1BR);
						for (int j=0;j<numCoeffs;j++) 
						{
							sprintf(refList[j],"%s",params.g1List[j]);
							coeffList[j] = params.channel[i].g1Coefs[j];
						}					
					}
				
					if (numCoeffs > 0)
					{
						strncpy(sensorCoef.sensorName, params.channel[i].name, 32);
						sensorCoef.coefRec.num_of_coefs = ToFile( (short)numCoeffs );
						
						// convert coefficients back to phiOs
						for (int j=0;j<numCoeffs;j++) 
						{
							strncpy(sensorCoef.coefRec.sensor_list[j], refList[j], 32);
							double coeff = coeffList[j];
							
							// have to undo multiplication by ratio of gains...
							for (int k=0; k< params.numChannels;k++)
							{
								if ( !strncmp( params.channel[k].name, refList[j], 5) ) 
								{
									// must multiply coefficient by ratio of refGain / sensorGain if applying to data in Tesla
									coeff *= params.channel[i].properGain / params.channel[k].properGain;
									break;
								}
							}
							sensorCoef.coefRec.coefs_list[j] = ToFile(coeff);
						}
						fwrite( &sensorCoef, sizeof(SensorCoefResRec), 1, fp );
					}
				}
			}
		}	// next channel			
	}
	
	fclose(fp);
	free( sensorRes4 );
	
	return true;
}


// D. Cheyne, Oct, 2010
// kludge to read CPersist format .infods file
// for now just want the correct bandpass of the data ...
//
bool readInfoDs( char *dsName, double * highPass, double * lowPass )
{
	FILE	*fp;
	char	infoName[256];
    char    dsBaseName[64];
    
	removeFilePath( dsName, dsBaseName);
	dsBaseName[strlen(dsBaseName)-3] = '\0';
	sprintf(infoName, "%s%s%s.infods", dsName,FILE_SEPARATOR, dsBaseName );
	
	if ( ( fp = fopen( infoName, "rb") ) == NULL )
	{
		return (false);
	}
	else
	{
		char s1[1];
		char s2[2];
		char s3[3];
		long tag;
		double dbl;
		
		while (!feof(fp))
		{
			bytesRead = fscanf(fp, "%c",s1);
			if (s1[0] == 'L')
			{
				bytesRead = fscanf(fp, "%c",s2);	
				bytesRead = fscanf(fp, "%c",s3);
				if (s2[0] == 'O' && s3[0] == 'W')
				{
					for (int i=0; i<11; i++) bytesRead = fscanf(fp, "%c", s1);
					dataSize = fread( &tag, sizeof( long ), 1, fp );
					dataSize = fread( &dbl, sizeof( double ), 1, fp );
					*highPass = ToHost(dbl);
				}
			}
			
			if (s1[0] == 'U')
			{
				bytesRead = fscanf(fp, "%c",s2);	
				bytesRead = fscanf(fp, "%c",s3);
				if (s2[0] == 'P' && s3[0] == 'P')
				{
					for (int i=0; i<11; i++) bytesRead = fscanf(fp, "%c", s1);
					dataSize = fread( &tag, sizeof( long ), 1, fp );
					dataSize = fread( &dbl, sizeof( double ), 1, fp );
					*lowPass = ToHost(dbl);		
				}
			}	
		}
		fclose(fp);
		return(true);
	}
}

bool readMEGResFile(  char *dsName, ds_params & params )
{
	char			ident[8];
	char			s[256];
    char            resName[256];
    char			sensorName[16];
	char			baseName[64];
	char			*sPtr;

	meg4GeneralResRec	grr4;
	NewSensorResRec		*sensorRes4 = NULL;
	SensorCoefResRec	sensorCoef;
	FILE *			    fp;
	
	unsigned char	aByte;
	double			aDouble;
	short			aShort;
	
	short			numFilters;
	double			filtFreq;
	int			    filtType;
	short			nCoeffs;
	int			    runDescLength;
	
    printf("readMEGResFile version %.1f...\n", CTFLIB_VERSION);
	removeFilePath( dsName, baseName);
	baseName[strlen(baseName)-3] = '\0';
	sprintf(resName, "%s%s%s.res4", dsName, FILE_SEPARATOR, baseName );

	if ( ( fp = fopen( resName, "rb") ) == NULL )
	{
		printf("couldn't open [%s]\n", resName);
		return(false);
	}
	//	printf("reading %s information\n", resName);
	
	dataSize = fread( ident, sizeof( char ), 8, fp );
	if ( strncmp( ident, "MEG4RES", 7 ) && 
		strncmp( ident, "MEG41RS", 7 ) && 
		strncmp( ident, "MEG42RS", 7) )
	{
		printf( "Not a valid MEG4 resource file\n");
		return(false);
	}
	
	strncpy(params.versionStr, ident, 8);
	
	dataSize = fread( &grr4, sizeof( meg4GeneralResRec ), 1, fp );
	
	// get collection parameters
	params.numSamples = ToHost( (int)grr4.gSetUp.no_samples );
	params.numChannels = ToHost( (short)grr4.gSetUp.no_channels );
	if( params.numChannels > MAX_CHANNELS )
	{
		fprintf(stderr,"Error: total number of channels exceeds maximum allowed\n");
		fprintf(stderr,"total channels = %d, maximum allowed = %d\n", params.numChannels, MAX_CHANNELS);
		return false;
	}
	
	params.numTrials = ToHost( (short)grr4.gSetUp.no_trials );
	params.numPreTrig = ToHost( (int)grr4.gSetUp.preTrigPts );
	params.sampleRate = ToHost( grr4.gSetUp.sample_rate );
	double totalTime = ToHost( grr4.gSetUp.epoch_time );
	params.trialDuration = totalTime / (double)params.numTrials;
	
	/* skip extra bytes */
	fseek(fp, 4, SEEK_CUR);
	
	/* run description - it is not clear if this has a limit but dsparams struct only allocates 512 bytes */
	runDescLength = ToHost( (int)grr4.nfSetUp.size );
	dataSize = fread( params.run_description, sizeof( char ), runDescLength, fp );
	if (runDescLength > 512)
	{
		printf("run description length is %d characters, truncating to 512...\n", runDescLength);
        runDescLength = 510;
	}
	params.run_description[runDescLength] = '\0';
	
	strncpy(params.run_title, grr4.nfSetUp.nf_run_title, 256);
	strncpy(params.operator_id, grr4.nfSetUp.nf_operator, 32);
	
	/* get num filters needed below */
	dataSize = fread( &numFilters, sizeof( short ), 1, fp );
	numFilters = ToHost( numFilters );
	
	/* get acquisition filter settings */
	
	params.highPass = 0;
	params.lowPass = params.sampleRate / 4.0;       // default -- overwritten below
 	
	int numBytes;
	for(int j=0; j<numFilters; j++ ) 
	{
		dataSize = fread( &filtFreq, sizeof( double ), 1, fp );
		fseek(fp, 4, SEEK_CUR);  		
		dataSize = fread( &filtType, sizeof( int ), 1, fp );
		
		if ( ToHost((int)filtType) == 1 )
			params.lowPass = ToHost( filtFreq );
		else if ( ToHost((int)filtType) == 2 )
			params.highPass = ToHost( filtFreq );
		
		dataSize = fread( &nCoeffs, sizeof( short ), 1, fp );  
		nCoeffs = ToHost( (short)nCoeffs );
		numBytes = nCoeffs * 8;	
		
		fseek(fp, numBytes, SEEK_CUR);
	}
	

	for (int i=0; i<params.numChannels; i++) 
	{
		dataSize = fread( sensorName, sizeof(unsigned char), 32, fp );
		strncpy( params.channel[i].name, sensorName, SENSOR_LABEL );
		params.channel[i].index = i;
	}
		
	sensorRes4 = ( NewSensorResRec *)malloc( params.numChannels * sizeof( NewSensorResRec ) );
	if ( sensorRes4 == NULL ) 
	{
		printf("Error allocating memory for sensor record\n");
		return( false);
	}
	
	dataSize = fread( sensorRes4, sizeof( NewSensorResRec ), params.numChannels, fp );
	
	
	// have all information we need, must now extract gains and position info...
	
	for (int i=0; i<params.numChannels; i++) 
	{
		// get sensor type first
		params.channel[i].sensorType = ToHost( sensorRes4[i].sensorTypeIndex);
		
		// modified July, 2012 - include magnetometer type sensors (channelType == 4) for Neuromag data that has been
		// converted to .ds format
		if ( params.channel[i].sensorType == eMEGSensor || params.channel[i].sensorType == eMEGSensor1 )   
		{
			params.channel[i].isSensor = true;
		}
		else
			params.channel[i].isSensor = false;

		//  only mag and 1st-order references exist
		if ( params.channel[i].sensorType == eMEGReference || params.channel[i].sensorType == eMEGReference1)   
		{
			params.channel[i].isReference = true;
		}
		else
			params.channel[i].isReference = false;
		
		// flag EEG channels for position information etc
		if ( params.channel[i].sensorType == eEEGSensor)   
		{
			params.channel[i].isEEG= true;
		}
		else
			params.channel[i].isEEG = false;
		
		
		int numCoils = 	ToHost( sensorRes4[i].numCoils);
		
		params.channel[i].numCoils = numCoils;
		
		int gradient = 	ToHost( sensorRes4[i].grad_order_no);
		if ( gradient == 13 )
			gradient = 4;	//  3rd + adaptive
		params.channel[i].gradient = gradient;
		
		double properGain = ToHost( sensorRes4[i].properGain );
		double qGain = ToHost( sensorRes4[i].qGain );	
		double ioGain = ToHost( sensorRes4[i].ioGain );		// corrected Sept, 2019 - ioGain is used by ADC channels = 1.0 for MEG
		
		params.channel[i].properGain = properGain;
		params.channel[i].qGain = qGain;
		params.channel[i].ioGain = ioGain;			// added field to ds_params Aug, 2020
		params.channel[i].gain = properGain * qGain * ioGain;
		
		// read position information for all sensor types since some non MEG channels have meaningful locations (e.g., CHL). 
			
		// get effective coil surface area ** note area and numturns only valid in the coilTbl
		int numTurns = ToHost( sensorRes4[i].coilTbl[0].numturns );
		double coilArea = ToHost( (double)sensorRes4[i].coilTbl[0].area );
		params.channel[i].numTurns = numTurns;
		params.channel[i].coilArea = coilArea;
		
		double x;
		double y;
		double z;
		
		x = ToHost( (double)sensorRes4[i].HdcoilTbl[0].position.c.x );
		y = ToHost( (double)sensorRes4[i].HdcoilTbl[0].position.c.y );
		z = ToHost( (double)sensorRes4[i].HdcoilTbl[0].position.c.z );
		params.channel[i].xpos = x;
		params.channel[i].ypos = y;
		params.channel[i].zpos = z;
		
		if ( numCoils > 1 )
		{
			x = ToHost( (double)sensorRes4[i].HdcoilTbl[1].position.c.x );
			y = ToHost( (double)sensorRes4[i].HdcoilTbl[1].position.c.y );
			z = ToHost( (double)sensorRes4[i].HdcoilTbl[1].position.c.z );
			
			params.channel[i].xpos2 = x;
			params.channel[i].ypos2 = y;
			params.channel[i].zpos2 = z;
		}
				
		x = ToHost( (double)sensorRes4[i].HdcoilTbl[0].orient.c.x );
		y = ToHost( (double)sensorRes4[i].HdcoilTbl[0].orient.c.y );
		z = ToHost( (double)sensorRes4[i].HdcoilTbl[0].orient.c.z );

		params.channel[i].p1x = x;
		params.channel[i].p1y = y;
		params.channel[i].p1z = z;
		if ( numCoils > 1 )
		{
			x = ToHost( (double)sensorRes4[i].HdcoilTbl[1].orient.c.x );
			y = ToHost( (double)sensorRes4[i].HdcoilTbl[1].orient.c.y );
			z = ToHost( (double)sensorRes4[i].HdcoilTbl[1].orient.c.z );

			params.channel[i].p2x = x;
			params.channel[i].p2y = y;
			params.channel[i].p2z = z;
		}
		
		// read dewar coordinates
		x = ToHost( (double)sensorRes4[i].coilTbl[0].position.c.x );
		y = ToHost( (double)sensorRes4[i].coilTbl[0].position.c.y );
		z = ToHost( (double)sensorRes4[i].coilTbl[0].position.c.z );
		params.channel[i].xpos_dewar = x;
		params.channel[i].ypos_dewar = y;
		params.channel[i].zpos_dewar = z;
		
		if ( numCoils > 1 )
		{
			x = ToHost( (double)sensorRes4[i].coilTbl[1].position.c.x );
			y = ToHost( (double)sensorRes4[i].coilTbl[1].position.c.y );
			z = ToHost( (double)sensorRes4[i].coilTbl[1].position.c.z );
			
			params.channel[i].xpos2_dewar = x;
			params.channel[i].ypos2_dewar = y;
			params.channel[i].zpos2_dewar = z;
		}
		
		x = ToHost( (double)sensorRes4[i].coilTbl[0].orient.c.x );
		y = ToHost( (double)sensorRes4[i].coilTbl[0].orient.c.y );
		z = ToHost( (double)sensorRes4[i].coilTbl[0].orient.c.z );
		
		params.channel[i].p1x_dewar = x;
		params.channel[i].p1y_dewar = y;
		params.channel[i].p1z_dewar = z;
		if ( numCoils > 1 )
		{
			x = ToHost( (double)sensorRes4[i].coilTbl[1].orient.c.x );
			y = ToHost( (double)sensorRes4[i].coilTbl[1].orient.c.y );
			z = ToHost( (double)sensorRes4[i].coilTbl[1].orient.c.z );
			
			params.channel[i].p2x_dewar = x;
			params.channel[i].p2y_dewar = y;
			params.channel[i].p2z_dewar = z;
		}			

	} // next channel
	
	free ( sensorRes4 );
	
	// 
	short numCoeff_recs;
	dataSize = fread( &aShort, sizeof( short), 1, fp );
	numCoeff_recs = ToHost(aShort);
	
	if (numCoeff_recs > 0)
	{	
		params.hasBalancingCoefs = true;
		// D. Cheyne, Oct 2010.   Notes on reading SensorCoefResRec data:
		// - numCoeff_recs indicates how many records were written = numReferences + (6 x numSensors) -
		// - primary sensor channels have 6 records each, 1st,2nd, 3rd order, 3 order+adapt in addition to 2nd and 3rd order ideal (G20I and G3OI)
		// - these appear to be written out in reverse order so must scan for names
		// - reference channels have only one record each since they only have 1st order coefficients 
		// - magnetometers have 1st order coefficients but they are all set to zero.
		// 
		// below we ignore the ideal coefficients when reading 
		
		char refName[256];
		
		short coef_count = 0;
		while (!feof(fp) )
		{
			dataSize = fread( &sensorCoef, sizeof( SensorCoefResRec ),1 , fp );
			int numCoefs = ToHost(sensorCoef.coefRec.num_of_coefs);
			int coefType = (int)ToHost( (int)sensorCoef.coefType );
			
			// get coefficients for 1st, 2nd, 3rd, and 3rd + adaptive balancing
			// Note that we must convert them to Tesla by multiplying by ratio of proper gains to apply to data in Tesla...
			// also  - we ignore ideal coefficients since they are no longer used in forward modeling 
			if ( coefType == 0x47314252 || coefType == 0x47324252 || 
				coefType == 0x47334252 || coefType == 0x47334152 )
			{
				coef_count++;
//				printf("record %d,  channel %s, numCoefs = %d,  coefType = %x\n", coef_count, sensorCoef.sensorName, numCoefs, coefType);
				
				for (int i=0; i< params.numChannels; i++)
				{
					// find the sensor channel for this record...
					if ( !strncmp( params.channel[i].name, sensorCoef.sensorName, 5 ) )
					{
						// read balancing rec for this sensor channel (index = i), one of four possible gradients
						for (int j=0; j<numCoefs; j++)
						{
							// for each coefficient get its ref channel and coefficient in phi 0
							sprintf(refName, "%s", sensorCoef.coefRec.sensor_list[j] );
							double coeff = ToHost(sensorCoef.coefRec.coefs_list[j]);
							
							// have to search for the gain of this reference channel (index = k) to convert coefficient to Tesla
							for (int k=0; k< params.numChannels;k++)
							{
								if ( !strncmp( params.channel[k].name, refName, 5) ) 
								{
									// must multiply coefficient by ratio of refGain / sensorGain if applying to data in Tesla
									coeff *= params.channel[k].properGain / params.channel[i].properGain;
									break;
								}
							}
//							printf("balancing channel, coeff (in Tesla) = %s , %g\n", refName, coeff);
							
							// ** Nov, 2010 - D. Cheyne - correction to handling balancing lists 
							//  we need to have separate balancing lists for 1st/2nd and 3rd since even though 3rd list will contain 
							//  the 8 references from the full cross for 1st and 2nd order - 
							
							if ( coefType == 0x47314252 )
							{
								params.numG1Coefs = numCoefs;
								sprintf(params.g1List[j], "%s", refName);  // get balancing list for 1st / 2nd gradient ince it is comprehensive
								params.channel[i].g1Coefs[j] = coeff;
							}
							else if ( coefType == 0x47324252 )
							{
								params.numG2Coefs = numCoefs;
								params.channel[i].g2Coefs[j] = coeff;
							}
							else if ( coefType == 0x47334252 )
							{
								params.numG3Coefs = numCoefs;
								sprintf(params.g3List[j], "%s", refName);  // get balancing list for  3rd gradient or 3rd + adaptive
								params.channel[i].g3Coefs[j] = coeff;
							}
							else if ( coefType == 0x47334152 )
							{
								params.numG4Coefs = numCoefs;
								params.channel[i].g4Coefs[j] = coeff;
							}	  
						}
						break;  // goto next record
					}
				}
			}
			
		}
	}

	fclose( fp );
	

	// ** New - added more fields to ds_params to avoid computing these over and over...
	//
	params.numSensors = 0;
	
	for (int i=0; i<params.numChannels; i++)
	{
		if ( params.channel[i].isSensor )
			params.numSensors++;
	}
	if ( params.numSensors == 0)
	{
		printf( "*** Warning: no sensor channels in dataset, could not read gradient order and coefficients...  \n");
	}
	
	params.gradientOrder = -1;
	
	// set balancing ref flag - just need list from one sensor 
	for (int i=0; i<params.numChannels; i++)
	{
		if ( params.channel[i].isSensor )
		{
			params.gradientOrder = params.channel[i].gradient;  
			break;
		}
	}
	
	// set isBalancingRef flag - can use g3 list since it 
	// contains the g1 g2 references
	for (int j=0; j<params.numChannels; j++)
	{
		params.channel[j].isBalancingRef = false;
		if ( params.channel[j].isReference )
		{
			for (int k=0; k<params.numG3Coefs;k++)
			{
				if ( !strncmp( params.channel[j].name, params.g3List[k], 3) )
				{
					params.channel[j].isBalancingRef = true;
					break;
				}
			}
		}
	}
	
	if ( params.gradientOrder == -1)
		printf( "*** WARNING: could not get data gradient order (no sensor channels?) \n");

	params.numBalancingRefs = 0;
	params.numReferences = 0;
	for (int i=0; i<params.numChannels; i++)
	{
		if ( params.channel[i].isReference )
			params.numReferences++;
		if ( params.channel[i].isBalancingRef )
			params.numBalancingRefs++;
	}
	
	// ** note some CTF datasets will have negative preTrig points to indicate epoch starts 
	//    at a positive latency.  This can create havoc for other programs that assume preTrig is 
	//    either zero or a positive value and minTime is never greater than zero....
	//    By setting numPreTrig to zero here - data will be shifted to start at zero.
	
	if (params.numPreTrig < 0)
		params.numPreTrig = 0;
	
	if (params.numPreTrig == 0)
		params.epochMinTime = 0.0;
	else
		params.epochMinTime = -params.numPreTrig * (1.0/params.sampleRate);
	
	// there is always one sample at time zero 
	double numPostTrig = params.numSamples - params.numPreTrig -1;
	params.epochMaxTime = numPostTrig * (1.0/params.sampleRate);
	
	// give each channel its own sphere origin (in cm)  for multiSphere modelling
	for (int i=0; i<params.numChannels; i++)
	{
		params.channel[i].sphereX = 0.0;
		params.channel[i].sphereY = 0.0;
		params.channel[i].sphereZ = 0.0;
	}
	
	return (true);
}


// added Aug 2021 - need convenient way to check if we are dealing with multi-segment (large) datsets.
int getNumMEG4Segments( char *dsName )
{
	FILE 		*fp;
	int 		numSegments = 1;		// segment 1 is always .meg4
	char		megName[256];
	char 		basePath[64];
	char 		baseName[64];
	
	int len = strlen( dsName );
	strcpy( basePath, dsName);
	basePath[len-3] = '\0';
	
	removeFilePath( dsName, baseName);
	baseName[strlen(baseName)-3] = '\0';
	
	// only way to tell if multi-segmemt data and how many is if files with pre-fix exist...
	int fileNo = 0;
	while (1)
	{
		fileNo++;
		sprintf(megName, "%s%s%s.%d_meg4", dsName,FILE_SEPARATOR, baseName, fileNo);
		fp = fopen( megName, "rb");
		if (fp == NULL)
		{
			break;
		}
		else
		{
			numSegments++;
			fclose(fp);
		}
	}
	
	return( numSegments);
}

bool readMEGTrialData( char *dsName, const ds_params & params, double **trialArray, int trialNo, int gradientSelect, bool sensorsOnly)
{

	char		s[256];
	char		megName[256];
	char 		basePath[64];
	char 		baseName[64];

	char		*sPtr;
	FILE		*fp;
	double		d1;
	double		*arrayPtr;
	
	int			*trialBuffer;
	double		** refDataG1;
	double		** refDataG3;
	
	long int	trialOffset;        // version 5.2 - change pointers to long int to read large meg4 files !
    long int    pointsPerTrial;
    
	if ( trialArray == NULL )
	{
		return (false);
	}
				
	int len = strlen( dsName );
	strcpy( basePath, dsName);
	basePath[len-3] = '\0';

	removeFilePath( dsName, baseName);
	baseName[strlen(baseName)-3] = '\0';

	if ( trialNo < 0 || trialNo >= params.numTrials )
	{
		printf("invalid trial number\n");
		return (false);
	}	

	bool balanceData = false;
	if ( gradientSelect > -1 && params.gradientOrder != gradientSelect)
			balanceData = true;
	
	if (balanceData)
	{
		if ( gradientSelect == 1 && params.numG1Coefs == 0)
		{
			printf("no coefficients for gradient %d \n", gradientSelect);
			return(false);
		}
		else if ( gradientSelect == 2 && params.numG2Coefs == 0)
		{
			printf("no coefficients for gradient %d \n", gradientSelect);
			return(false);
		}
		else if ( gradientSelect == 3 && params.numG3Coefs == 0)
		{
			printf("no coefficients for gradient %d \n", gradientSelect);
			return(false);
		}
		else if ( gradientSelect == 4 && params.numG4Coefs == 0)
		{
			printf("no coefficients for gradient %d \n", gradientSelect);
			return(false);
		}
	}
	
	int numSegments = 1;
	
	numSegments = getNumMEG4Segments(dsName);
	
	// read in one trial all channels, since we may need ref channels for balancing
	//
	pointsPerTrial = params.numChannels * params.numSamples;
	trialBuffer = (int *)malloc( sizeof(int) * pointsPerTrial);
	if ( trialBuffer == NULL)
	{
		printf("memory allocation failed for trial buffer\n");
		return(false);
	}
	
	//  -- get trial offset. If multisegment data this is start of next .meg4 segment

	if (numSegments == 1)
	{
		sprintf(megName, "%s%s%s.meg4", dsName,FILE_SEPARATOR, baseName );
		trialOffset = trialNo * pointsPerTrial * sizeof(int);
	}
	else
	{
		trialOffset = 0;
		if (trialNo == 0)
			sprintf(megName, "%s%s%s.meg4", dsName,FILE_SEPARATOR, baseName);
		else
			sprintf(megName, "%s%s%s.%d_meg4", dsName,FILE_SEPARATOR, baseName, trialNo);
	}
	
	// open data file and start reading...
	//
	if ( ( fp = fopen( megName, "rb") ) == NULL )
	{
		return(false);
	}
	dataSize = fread( s, sizeof( char ), 8, fp );
	if ( strncmp( s, "MEG4CPT", 7 ) && strncmp( s, "MEG41CP", 7 )  )
		return(false);

	if( trialOffset < 0)
	{
		// Exceeded largest int value causing a wrap-around
		printf("\nNegative file offset encountered. Dataset may be too large." );
		return(false);
	}
	
	fseek( fp, trialOffset, SEEK_CUR);
	dataSize = fread( trialBuffer, sizeof(int), pointsPerTrial, fp);

	// read balancing data into separate arrays for balancing sensor channels 
	//
	if (balanceData)
	{
		refDataG1 = (double **)malloc(sizeof(double *) * params.numG1Coefs);
		for (int i=0; i< params.numG1Coefs; i++)
		{
			refDataG1[i] = (double *)malloc( sizeof(double) *  params.numSamples);
			if ( refDataG1[i] == NULL)
			{
				printf("Memory allocation error for ref data");
				return(false);
			}
		}
		refDataG3 = (double **)malloc(sizeof(double *) * params.numG3Coefs);
		for (int i=0; i< params.numG3Coefs; i++)
		{
			refDataG3[i] = (double *)malloc( sizeof(double) *  params.numSamples);
			if ( refDataG3[i] == NULL)
			{
				printf("Memory allocation error for ref data");
				return(false);
			}
		}		
		
		// Nov 2010 - rewrite of this code to be more efficient and get correct references
		//           also need to put  balancing channel data for G1 and G3 in separate arrays
		int refCount = 0;              
		for (int j=0; j<params.numChannels; j++)
		{	
			if (!params.channel[j].isBalancingRef) continue;
			for (int k=0; k<params.numG3Coefs; k++)
			{
				// put  balancing channel data for G1 and G3 in separate arrays
				if ( !strncmp( params.g3List[k], params.channel[j].name, 5) )
				{
					int * channelPtr = trialBuffer + (int)(j * params.numSamples);
					double thisGain =  params.channel[j].gain;
					for (int sample=0; sample<params.numSamples;sample++)
						refDataG3[refCount][sample] = ToHost( (int)*channelPtr++  ) / thisGain;
					refCount++;
					
					break;
				}
				
			}		
		}
		refCount = 0;
		for (int j=0; j<params.numChannels; j++)
		{	
			if (!params.channel[j].isBalancingRef) continue;
			for (int k=0; k<params.numG1Coefs; k++)
			{
				if ( !strncmp( params.g1List[k], params.channel[j].name, 5) )
				{
					int * channelPtr = trialBuffer + (int)(j * params.numSamples);
					double thisGain =  params.channel[j].gain;
					for (int sample=0; sample<params.numSamples;sample++)
						refDataG1[refCount][sample] = ToHost( (int)*channelPtr++  ) / thisGain;
					refCount++;
					
					break;
				}
				
			}		
		}
	}
	
	
	// read data
	int chanCount = 0;

	for (int i = 0; i<params.numChannels; i++)
	{			
		if ( sensorsOnly && !params.channel[i].isSensor ) 		//  if only reading sensor data ...
			continue;

		// now read the sensor channel data
        
		int * channelPtr = trialBuffer + (int)(i * params.numSamples);
		double thisGain =  params.channel[i].gain;
		
		// read data and convert by gain for this channel
		for (int k=0; k<params.numSamples; k++ )
		{
			d1 = ToHost( (int)*channelPtr++  ) / thisGain;
			trialArray[chanCount][k] = d1;
		}

		// if this is a sensor and gradient other than file gradient was selected, balance the data 
		//		
		if ( params.channel[i].isSensor && balanceData )
		{
			// if gradient data, need to convert to raw by adding back sum of weighted reference array
			// i.e., performing reverse operation to balancing
			if ( params.gradientOrder > 0 )
			{
				if ( params.gradientOrder == 1 )
				{
					for (int sample=0; sample<params.numSamples; sample++)
					{
						d1 = 0.0;
						for (int k=0; k<params.numG1Coefs; k++)
						{
							d1 += params.channel[i].g1Coefs[k] * refDataG1[k][sample];
						}
						trialArray[chanCount][sample] += d1;
					}
				}
				else if ( params.gradientOrder == 2 )
				{
					for (int sample=0; sample<params.numSamples; sample++)
					{
						d1 = 0.0;
						for (int k=0; k<params.numG2Coefs; k++)
						{
							d1 += params.channel[i].g2Coefs[k] * refDataG1[k][sample];
						}
						trialArray[chanCount][sample] += d1;
					}
				}
				else if ( params.gradientOrder == 3 )
				{
					for (int sample=0; sample<params.numSamples; sample++)
					{
						d1 = 0.0;
						for (int k=0; k<params.numG3Coefs; k++)
						{
							d1 += params.channel[i].g3Coefs[k] * refDataG3[k][sample];
						}
						trialArray[chanCount][sample] += d1;
					}
				}
				else if ( params.gradientOrder == 4 )
				{
					for (int sample=0; sample<params.numSamples; sample++)
					{
						d1 = 0.0;
						for (int k=0; k<params.numG4Coefs; k++)
						{
							d1 += params.channel[i].g4Coefs[k] * refDataG3[k][sample];
						}
						trialArray[chanCount][sample] += d1;
					}
				}	
				
			}
			
			// balance the data from raw to requested gradient by subtracting sum of weighted reference array
			//
			if (gradientSelect > 0 )
			{
				printf("balancing data to gradient %d...\n", gradientSelect);
				if ( gradientSelect == 1 )
				{
					for (int sample=0; sample<params.numSamples; sample++)
					{
						d1 = 0.0;
						for (int k=0; k<params.numG1Coefs; k++)
						{
							d1 += params.channel[i].g1Coefs[k] * refDataG1[k][sample];
						}
						trialArray[chanCount][sample] -= d1;
					}
				}
				else if ( gradientSelect == 2 )
				{
					for (int sample=0; sample<params.numSamples; sample++)
					{
						d1 = 0.0;
						for (int k=0; k<params.numG2Coefs; k++)
						{
							d1 += params.channel[i].g2Coefs[k] * refDataG1[k][sample];
						}
						trialArray[chanCount][sample] -= d1;
					}
				}
				else if ( gradientSelect == 3 )
				{
					for (int sample=0; sample<params.numSamples; sample++)
					{
						d1 = 0.0;
						for (int k=0; k<params.numG3Coefs; k++)
						{
							d1 += params.channel[i].g3Coefs[k] * refDataG3[k][sample];
						}
						trialArray[chanCount][sample] -= d1;
					}
				}
				else if ( gradientSelect == 4 )
				{
					for (int sample=0; sample<params.numSamples; sample++)
					{
						d1 = 0.0;
						for (int k=0; k<params.numG4Coefs; k++)
						{
							d1 += params.channel[i].g4Coefs[k] * refDataG3[k][sample];
						}
						trialArray[chanCount][sample] -= d1;
					}
				}	
			}
		}
		chanCount++;
	}

	if (balanceData)
	{
		for (int i=0; i<params.numG1Coefs; i++)
			free(refDataG1[i]);
		free (refDataG1);
		for (int i=0; i<params.numG3Coefs; i++)
			free(refDataG3[i]);
		free (refDataG3);
	}		
		
	free( trialBuffer );

	fclose( fp );

	return (true);
}

bool readMEGChannelData( char *dsName, const ds_params & params, char *channelName, double *chanArray, int trialNo, int gradientSelect)
{
	
	char		s[256];
	char		megName[256];
	char 		basePath[64];
	char 		baseName[64];
	
	char		*sPtr;
	FILE		*fp;
	double		d1;
	double		*arrayPtr;
	
	int			*trialBuffer;
    long int    trialOffset;        // version 5.2 - change pointers to long int to read large meg4 files !
    long int    pointsPerTrial;
    
	
	if ( chanArray == NULL )
	{
		return (false);
	}
	
	int len = strlen( dsName );
	strcpy( basePath, dsName);
	basePath[len-3] = '\0';
	
	removeFilePath( dsName, baseName);
	baseName[strlen(baseName)-3] = '\0';
	sprintf(megName, "%s%s%s.meg4", dsName,FILE_SEPARATOR, baseName );
	
	if ( trialNo < 0 || trialNo >= params.numTrials )
	{
		return (false);
	}	

	// get channel by comparing channel name against current channel
	bool foundChannel = false;
	int channelIndex;
		
	for (int i=0; i<params.numChannels; i++)
	{
		if (strncmp(channelName, params.channel[i].name, strlen(channelName) ) == 0)
		{
			channelIndex = i;
			foundChannel = true;
			break;
		}
	}
	
	if ( !foundChannel )
		return(false);

	bool balanceData = false;
	if ( gradientSelect > -1 && params.channel[channelIndex].isSensor && params.gradientOrder != gradientSelect)
		balanceData = true;
	
	if (balanceData)
	{
		if ( gradientSelect == 1 && params.numG1Coefs == 0)
		{
			printf("no coefficients for gradient %d \n", gradientSelect);
			return(false);
		}
		else if ( gradientSelect == 2 && params.numG2Coefs == 0)
		{
			printf("no coefficients for gradient %d \n", gradientSelect);
			return(false);
		}
		else if ( gradientSelect == 3 && params.numG3Coefs == 0)
		{
			printf("no coefficients for gradient %d \n", gradientSelect);
			return(false);
		}
		else if ( gradientSelect == 4 && params.numG4Coefs == 0)
		{
			printf("no coefficients for gradient %d \n", gradientSelect);
			return(false);
		}
	}
	
	// open data file and start reading...
	//
	if ( ( fp = fopen( megName, "rb") ) == NULL )
	{
		return(false);
	}
	
	dataSize = fread( s, sizeof( char ), 8, fp );
	if ( strncmp( s, "MEG4CPT", 7 ) && strncmp( s, "MEG41CP", 7 )  )
		return(false);
	
	// read in one trial all channels, since we may need ref channels for balancing
	//
	pointsPerTrial = params.numChannels * params.numSamples;
	
	trialBuffer = (int *)malloc( sizeof(int) * pointsPerTrial);
	if ( trialBuffer == NULL)
	{
		printf("memory allocation failed for trial buffer\n");
		return(false);
	}
	
	//  -- jump to trial offset and read  the trial data for all channels
	trialOffset = trialNo * pointsPerTrial * sizeof(int);
	if( trialOffset < 0)
	{
	    // Exceeded largest int value causing a wrap-around
        printf("\nNegative file offset encountered. Dataset may be too large." );
	    return(false);
	}
	fseek( fp, trialOffset, SEEK_CUR);
	dataSize = fread( trialBuffer, sizeof(int), pointsPerTrial, fp);
	
	
	// read the requested sensor data
	//	
	int * channelPtr = trialBuffer + (int)(channelIndex * params.numSamples);
	double thisGain =  params.channel[channelIndex].gain;
	
	// read data and convert to Tesla for this channel
	for (int k=0; k<params.numSamples; k++ )
	{
		d1 = ToHost( (int)*channelPtr++  ) / thisGain;
		chanArray[k] = d1;
	}
	
	
	// if balancing is requested we also need to read in  the reference channel data... 
	// read the reference data once here - this is more efficient for reading multiple channels
	
	if (params.channel[channelIndex].isSensor && balanceData )
	{
		// if this is a sensor and gradient other than file gradient was selected, balance the data 
		//
		
		double ** refDataG1 = (double **)malloc(sizeof(double *) * params.numG1Coefs);
		for (int i=0; i< params.numG1Coefs; i++)
		{
			refDataG1[i] = (double *)malloc( sizeof(double) *  params.numSamples);
			if ( refDataG1[i] == NULL)
			{
				printf("Memory allocation error for ref data");
				return(false);
			}
		}
		double ** refDataG3 = (double **)malloc(sizeof(double *) * params.numG3Coefs);
		for (int i=0; i< params.numG3Coefs; i++)
		{
			refDataG3[i] = (double *)malloc( sizeof(double) *  params.numSamples);
			if ( refDataG3[i] == NULL)
			{
				printf("Memory allocation error for ref data");
				return(false);
			}
		}		
		
		// Nov 2010 - rewrite of this code to be more efficient and get correct references
		//           also need to put  balancing channel data for G1 and G3 in separate arrays
		int refCount = 0;              
		for (int j=0; j<params.numChannels; j++)
		{	
			if (!params.channel[j].isBalancingRef) continue;
			for (int k=0; k<params.numG3Coefs; k++)
			{
				// put  balancing channel data for G1 and G3 in separate arrays
				if ( !strncmp( params.g3List[k], params.channel[j].name, 5) )
				{
					int * channelPtr = trialBuffer + (int)(j * params.numSamples);
					double thisGain =  params.channel[j].gain;
					for (int sample=0; sample<params.numSamples;sample++)
						refDataG3[refCount][sample] = ToHost( (int)*channelPtr++  ) / thisGain;
					refCount++;
					
					break;
				}
				
			}		
		}
		refCount = 0;
		for (int j=0; j<params.numChannels; j++)
		{	
			if (!params.channel[j].isBalancingRef) continue;
			for (int k=0; k<params.numG1Coefs; k++)
			{
				if ( !strncmp( params.g1List[k], params.channel[j].name, 5) )
				{
					int * channelPtr = trialBuffer + (int)(j * params.numSamples);
					double thisGain =  params.channel[j].gain;
					for (int sample=0; sample<params.numSamples;sample++)
						refDataG1[refCount][sample] = ToHost( (int)*channelPtr++  ) / thisGain;
					refCount++;
					
					break;
				}
				
			}		
		}
	
		if ( params.gradientOrder > 0 )
		{
			// if gradient data, need to convert to raw by adding back sum of weighted reference array
			// i.e., performing reverse operation to balancing
			printf("unbalancing data from gradient %d...  \n", params.gradientOrder);
			if ( params.gradientOrder == 1 )
			{
				for (int sample=0; sample<params.numSamples; sample++)
				{
					d1 = 0.0;
					for (int k=0; k<params.numG1Coefs; k++)
					{
						d1 += params.channel[channelIndex].g1Coefs[k] * refDataG1[k][sample];
					}
					chanArray[sample] += d1;
				}
			}
			else if ( params.gradientOrder == 2 )
			{
				for (int sample=0; sample<params.numSamples; sample++)
				{
					d1 = 0.0;
					for (int k=0; k<params.numG2Coefs; k++)
					{
						d1 += params.channel[channelIndex].g2Coefs[k] * refDataG1[k][sample];
					}
					chanArray[sample] += d1;
				}
			}
			else if ( params.gradientOrder == 3 )
			{
				for (int sample=0; sample<params.numSamples; sample++)
				{
					d1 = 0.0;
					for (int k=0; k<params.numG3Coefs; k++)
					{
						d1 += params.channel[channelIndex].g3Coefs[k] * refDataG3[k][sample];
					}
					chanArray[sample] += d1;
				}
			}
			else if ( params.gradientOrder == 4 )
			{
				for (int sample=0; sample<params.numSamples; sample++)
				{
					d1 = 0.0;
					for (int k=0; k<params.numG4Coefs; k++)
					{
						d1 += params.channel[channelIndex].g4Coefs[k] * refDataG3[k][sample];
					}
					chanArray[sample] += d1;
				}
			}	

		}
		
		// balance the data from raw to requested gradient by subtracting sum of weighted reference array
		//
		if (gradientSelect > 0 )
		{
			printf("balancing data to gradient %d...\n", gradientSelect);
			if ( gradientSelect == 1 )
			{
				for (int sample=0; sample<params.numSamples; sample++)
				{
					d1 = 0.0;
					for (int k=0; k<params.numG1Coefs; k++)
					{
						d1 += params.channel[channelIndex].g1Coefs[k] * refDataG1[k][sample];
					}
					chanArray[sample] -= d1;
				}
			}
			else if ( gradientSelect == 2 )
			{
				for (int sample=0; sample<params.numSamples; sample++)
				{
					d1 = 0.0;
					for (int k=0; k<params.numG2Coefs; k++)
					{
						d1 += params.channel[channelIndex].g2Coefs[k] * refDataG1[k][sample];
					}
					chanArray[sample] -= d1;
				}
			}
			else if ( gradientSelect == 3 )
			{
				for (int sample=0; sample<params.numSamples; sample++)
				{
					d1 = 0.0;
					for (int k=0; k<params.numG3Coefs; k++)
					{
						d1 += params.channel[channelIndex].g3Coefs[k] * refDataG3[k][sample];
					}
					chanArray[sample] -= d1;
				}
			}
			else if ( gradientSelect == 4 )
			{
				for (int sample=0; sample<params.numSamples; sample++)
				{
					d1 = 0.0;
					for (int k=0; k<params.numG4Coefs; k++)
					{
						d1 += params.channel[channelIndex].g4Coefs[k] * refDataG3[k][sample];
					}
					chanArray[sample] -= d1;
				}
			}	
		}
		
		for (int i=0; i<params.numG1Coefs; i++)
			free(refDataG1[i]);
		free (refDataG1);
		for (int i=0; i<params.numG3Coefs; i++)
			free(refDataG3[i]);
		free (refDataG3);
		
	}
		
	free( trialBuffer );
	
	fclose( fp );
	
	return (true);
}

// modified from getMEGSensorAverage in bwlib to read all trials and return average - removed filtering, added options for gradient and sensors only
bool readMEGDataAverage(char *dsName, ds_params & dsParams, double **megAve, int gradientSelect, bool sensorsOnly)
{
	double			mean;
	int				numChannels;
	
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
	
	// May 2022 - fixed bug for version 4.0
	// memory error if called with sensorsOnly = false
	
	if (sensorsOnly)
		numChannels =  dsParams.numSensors;
	else
		numChannels =  dsParams.numChannels;

	DS_trialArray = (double **)malloc( sizeof(double *) * numChannels );
	if (DS_trialArray == NULL)
	{
		printf("memory allocation failed for DS_trialArray ");
		return(false);
	}
	
	for (int i = 0; i < numChannels; i++)
	{
		DS_trialArray[i] = (double *)malloc( sizeof(double) * dsParams.numSamples);
		if ( DS_trialArray[i] == NULL)
		{
			printf( "memory allocation failed for DS_trialArray" );
			return(false);
		}
	}
	
	// zero average buffer
	for (int i=0; i < numChannels; i++)
		for (int j=0; j < dsParams.numSamples; j++)
			megAve[i][j] = 0.0;
	
	// average across all trials in dataset
	for (int i=0; i < dsParams.numTrials; i++)
	{
		if ( !readMEGTrialData( dsName, dsParams, DS_trialArray, i, gradientSelect, sensorsOnly) )
		{
			printf("Error reading .meg4 file\n");
			return(false);
		}
		
		for (int j=0; j < numChannels; j++)
		{
			// compute average MEG
			for (int k=0; k< dsParams.numSamples; k++)
				megAve[j][k] += DS_trialArray[j][k];
		}
	}
	
	// divide ave by N trials
	for (int j=0; j < numChannels; j++)
		for (int k=0; k< dsParams.numSamples; k++)
			megAve[j][k] /= (double)dsParams.numTrials;
	
	printf("freeing memory...\n");
	for (int i=0; i<numChannels; i++)
		free( DS_trialArray[i] );
	
	free( DS_trialArray );
	
	return (true);
}


int getNumSensors(  char *dsName, bool includeBalancingRefs )
{
	int 		numSensors = 0;

	if ( !readMEGResFile( dsName, DS_dsParams ) )
	{
		return(false);
	}	

	for (int i=0; i<DS_dsParams.numChannels; i++)
	{
		if ( DS_dsParams.channel[i].isSensor )
			numSensors++;
		else if ( includeBalancingRefs && DS_dsParams.channel[i].isBalancingRef )
			numSensors++;
	}
	
	return ( numSensors);
}

bool readHeadCoilFile( char *dsName, vectorCart & na,  vectorCart & le, vectorCart & re)
{
	FILE		*fp;
	char		fileName[256];
	char		baseName[64];
	char		inStr[256];
	char		tStr[256];
	
	removeFilePath( dsName, baseName);
	baseName[strlen(baseName)-3] = '\0';
	sprintf(fileName, "%s%s%s.hc", dsName,FILE_SEPARATOR, baseName );
	if ( ( fp = fopen( fileName, "r") ) == NULL )
	{
		printf("couldn't open head coil file [%s]\n", fileName);
		return(false);
	}
	
	while (!feof(fp))
	{
		// find dewar relative coil locations
		charPtr = fgets(inStr, 256, fp);
		if (strncmp(inStr,"measured nasion coil position relative to dewar (cm):", 53) == 0)
		{
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s %s %lf", tStr, tStr, &na.x);
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s %s %lf", tStr, tStr, &na.y);
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s %s %lf", tStr, tStr, &na.z);
			
		}
		else if (strncmp(inStr,"measured left ear coil position relative to dewar (cm):", 55) == 0)
		{
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s %s %lf", tStr, tStr, &le.x);
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s %s %lf", tStr, tStr, &le.y);
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s %s %lf", tStr, tStr, &le.z);
		}
		else if (strncmp(inStr,"measured right ear coil position relative to dewar (cm):", 56) == 0)
		{
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s %s %lf", tStr, tStr, &re.x);
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s %s %lf", tStr, tStr, &re.y);
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s %s %lf", tStr, tStr, &re.z);
		}
	}

	return(true);
	
	
}

bool writeHeadCoilFile( char *dsName, const vectorCart & na,  const vectorCart & le,  const vectorCart & re)
{
	FILE			*fp;
	char			fileName[256];
	char			baseName[64];
	vectorCart		naHead;
	vectorCart		leHead;
	vectorCart		reHead;
    affine			tmat;
	
	removeFilePath( dsName, baseName);
	baseName[strlen(baseName)-3] = '\0';
	sprintf(fileName, "%s%s%s.hc", dsName,FILE_SEPARATOR, baseName );	
	if ( ( fp = fopen( fileName, "w") ) == NULL ) 
	{
		printf("couldn't create file [%s]\n", fileName);
		return(false);
	}
	
	// measured positions relative to head are just the fids transformed into
	// their own coordinate system
	getCTFHeadTransformation(na, le, re, tmat);
	
	naHead = vectorXaffine( na, tmat);
	leHead = vectorXaffine( le, tmat);
	reHead = vectorXaffine( re, tmat);
	
	// default head position
	fprintf(fp, "standard nasion coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = 2.82843\n");
	fprintf(fp, "\ty = 2.82843\n");
	fprintf(fp, "\tz = -27\n");
	fprintf(fp, "standard left ear coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = -2.82843\n");
	fprintf(fp, "\ty = 2.82843\n");
	fprintf(fp, "\tz = -27\n");	
	fprintf(fp, "standard right ear coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = 2.82843\n");
	fprintf(fp, "\ty = -2.82843\n");
	fprintf(fp, "\tz = -27\n");	
	fprintf(fp, "standard inion coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = -2.82843\n");
	fprintf(fp, "\ty = -2.82843\n");
	fprintf(fp, "\tz = -27\n");	
	fprintf(fp, "standard Cz coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = 0\n");
	fprintf(fp, "\ty = 0\n");
	fprintf(fp, "\tz = -23\n");	
	
	// head relative to dewar - only meaningful values in file.
	//////
	fprintf(fp, "measured nasion coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = %8.5f\n", na.x);
	fprintf(fp, "\ty = %8.5f\n", na.y);
	fprintf(fp, "\tz = %8.5f\n", na.z);
	fprintf(fp, "measured left ear coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = %8.5f\n", le.x);
	fprintf(fp, "\ty = %8.5f\n", le.y);
	fprintf(fp, "\tz = %8.5f\n", le.z);	
	fprintf(fp, "measured right ear coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = %8.5f\n", re.x);
	fprintf(fp, "\ty = %8.5f\n", re.y);
	fprintf(fp, "\tz = %8.5f\n", re.z);
	fprintf(fp, "measured inion coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = 0\n");
	fprintf(fp, "\ty = 0\n");
	fprintf(fp, "\tz = 0\n");
	fprintf(fp, "measured Cz coil position relative to dewar (cm):\n");
	fprintf(fp, "\tx = 0\n");
	fprintf(fp, "\ty = 0\n");
	fprintf(fp, "\tz = 0\n");

	fprintf(fp, "measured nasion coil position relative to head (cm):\n");
	fprintf(fp, "\tx = %8.5f\n", naHead.x);
	fprintf(fp, "\ty = %8.5f\n", naHead.y);
	fprintf(fp, "\tz = %8.5f\n", naHead.z);
	fprintf(fp, "measured left ear coil position relative to head (cm):\n");
	fprintf(fp, "\tx = %8.5f\n", leHead.x);
	fprintf(fp, "\ty = %8.5f\n", leHead.y);
	fprintf(fp, "\tz = %8.5f\n", leHead.z);
	fprintf(fp, "measured right ear coil position relative to head (cm):\n");
	fprintf(fp, "\tx = %8.5f\n", reHead.x);
	fprintf(fp, "\ty = %8.5f\n", reHead.y);
	fprintf(fp, "\tz = %8.5f\n", reHead.z);
	fprintf(fp, "measured inion coil position relative to head (cm):\n");
	fprintf(fp, "\tx = 0.0\n");
	fprintf(fp, "\ty = 0.0\n");
	fprintf(fp, "\tz = 0.0\n");
	fprintf(fp, "measured Cz coil position relative to head (cm):\n");
	fprintf(fp, "\tx = 0.0\n");
	fprintf(fp, "\ty = 0.0\n");
	fprintf(fp, "\tz = 0.0\n");
	
	fclose(fp);
	
	return (true);
}
	
bool readGeomFile( char *fileName, ds_params & params)
{
	FILE		*fp;
	char		tStr[256];
	char		inStr[64];
	int			numChannels;
	char		name[32];
	char		previousName[32];
	double		gain1;
	double		gain2;
	int			numCoils;
	int			numTurns;
	double		area;
	double		x;
	double		y;
	double		z;
	double		xo;
	double		yo;
	double		zo;
	
	// write sensor geometry for a CTF dataset.
	printf("Reading sensor geometry from file [%s]\n", fileName);
	if ( ( fp = fopen( fileName, "r") ) == NULL ) 
	{
		printf("couldn't open [%s]\n", fileName);
		return(false);
	}
	
	numChannels = 0;
	while (!feof(fp))
	{
		charPtr = fgets(inStr, 256, fp);
		
		sscanf(inStr,"%s",tStr);  // check input
		
		// skip comment lines starting with pound sign
		if (!strncmp(tStr,"#",1))
			continue;
				
		sscanf(inStr, "%s %lf %lf %d %d %lf %lf %lf %lf %lf %lf %lf", 
			   name, &gain1,&gain2,&numCoils, 
			   &numTurns, &area, &x, &y, &z, &xo, &yo, &zo);

		// this avoids duplicate entries due to linefeeds at end of file ...
//		if (!strcmp(name, previousName))
//			continue;
		
		
		sprintf(params.channel[numChannels].name, "%s", name);
		params.channel[numChannels].qGain = gain1;
		params.channel[numChannels].properGain = gain2;
		params.channel[numChannels].ioGain = 1.0;		// now exist and is used in params struct
		params.channel[numChannels].numCoils = numCoils;
		params.channel[numChannels].numTurns = numTurns;
		params.channel[numChannels].coilArea = area;
		params.channel[numChannels].xpos = x;
		params.channel[numChannels].ypos = y;
		params.channel[numChannels].zpos = z;
		params.channel[numChannels].p1x = xo;
		params.channel[numChannels].p1y = yo;
		params.channel[numChannels].p1z = zo;	
		
		if (numCoils == 2)
		{
			sscanf(inStr, "%s %lf %lf %d %d %lf %lf %lf %lf %lf %lf %lf %d %lf %lf %lf %lf %lf %lf %lf", 
				   name, &gain1,&gain2,&numCoils,
				   &numTurns, &area, &x, &y, &z, &xo, &yo, &zo,
				   &numTurns, &area, &x, &y, &z, &xo, &yo, &zo);
			
			params.channel[numChannels].xpos2 = x;
			params.channel[numChannels].ypos2 = y;
			params.channel[numChannels].zpos2 = z;
			params.channel[numChannels].p2x = xo;
			params.channel[numChannels].p2y = yo;
			params.channel[numChannels].p2z = zo;	
		}
		
		// set other channel info
		params.channel[numChannels].index = numChannels;
		params.channel[numChannels].isSensor = true;
		params.channel[numChannels].isReference = false;
		params.channel[numChannels].isBalancingRef = false;
		params.channel[numChannels].gradient = 0;
		params.channel[numChannels].gain = params.channel[numChannels].properGain * params.channel[numChannels].qGain;
		if (params.channel[numChannels].numCoils == 1)
			params.channel[numChannels].sensorType = 4;	
		else if (params.channel[numChannels].numCoils == 2)
			params.channel[numChannels].sensorType = 5;	
		
		numChannels++;
		
		sprintf(previousName, "%s",name);
		
		
	}
	
	// set some critical header values for CTF datasets.
	sprintf(params.versionStr, "MEG42RS"); 
	
	printf("read info for %d MEG sensor channels\n", numChannels);
	params.numChannels = numChannels;
	params.numSensors = numChannels;
	params.numReferences = 0;
	params.numBalancingRefs = 0;
	
	fclose(fp);
	
	return(true);
}

bool writeGeomFile( char *fileName, const ds_params & params, bool sensorsOnly)
{
	FILE	*fp;
	
	// write sensor geometry for a CTF dataset.
	printf("Saving sensor geometry in file [%s]\n", fileName);
	if ( ( fp = fopen( fileName, "w") ) == NULL ) 
	{
		printf("couldn't open [%s]\n", fileName);
		return(false);
	}

	fprintf(fp, "# channel \tgain1\t       gain2\t\t numCoils turns area   xposition    yposition    zposition     xorientation    yorientation    zorientation  ...  turns area   xposition    yposition    zposition    xorientation    yorientation    zorientation ...  \n"); 
	for (int i=0; i<params.numChannels; i++)
	{
		if (params.channel[i].isSensor || ( params.channel[i].isReference && !sensorsOnly ))
		{
			fprintf(fp, "%s\t%12.6g\t%12.6g\t%d",params.channel[i].name, params.channel[i].qGain, params.channel[i].properGain, params.channel[i].numCoils);
					
			for (int k=0; k<params.channel[i].numCoils; k++)
			{
				if (k==0)
				{
					fprintf(fp, "\t%d\t%8.6f\t%12.6f\t%12.6f\t%12.6f\t%12.6f\t%12.6f\t%12.6f",
						params.channel[i].numTurns, 
						params.channel[i].coilArea, 
						params.channel[i].xpos,
						params.channel[i].ypos,
						params.channel[i].zpos,
						params.channel[i].p1x,
						params.channel[i].p1y,
						params.channel[i].p1z);
				}
				if (k==1)
				{
					fprintf(fp, "\t%d\t%8.6f\t%12.6f\t%12.6f\t%12.6f\t%12.6f\t%12.6f\t%12.6f",
							params.channel[i].numTurns, 
							params.channel[i].coilArea, 
							params.channel[i].xpos2,
							params.channel[i].ypos2,
							params.channel[i].zpos2,
							params.channel[i].p2x,
							params.channel[i].p2y,
							params.channel[i].p2z);
				}					
			}
			fprintf(fp,"\n");
		}
	}	
	
	fclose(fp);

    return(true);
}

bool printDsParams( ds_params & params, bool includeChannelRecs, bool includeCoeffs )
{        
	printf("Run description: %s\n", params.run_description);
	printf("Samples:         %d\n", params.numSamples);
	printf("numPreTrig:      %d\n", params.numPreTrig);
	printf("numChannels:     %d\n", params.numChannels);
	printf("numTrials:       %d\n", params.numTrials);
	printf("numSensors:      %d\n", params.numSensors);
	printf("numReferences:   %d\n", params.numReferences);

	
	printf("sampleRate:      %g\n", params.sampleRate);
	printf("trialDuration:   %g\n", params.trialDuration);
	printf("lowPass:         %g\n", params.lowPass);
	printf("highPass:        %g\n", params.highPass);
	printf("num sensors:     %d\n", params.numSensors);
	printf("num references:  %d\n", params.numReferences);
	printf("num balancing:   %d\n", params.numBalancingRefs);
	printf("epoch min time:  %g s\n", params.epochMinTime);
	printf("epoch max time:  %g s\n", params.epochMaxTime);
	printf("run title:  %s\n", params.run_title);
	printf("operator_id:  %s\n", params.operator_id);
	printf("trials averaged = %d\n", params.no_trials_avgd);
	printf("gradient = %d\n", params.gradientOrder);
	
	if ( includeChannelRecs )
	{
		if ( includeCoeffs )
		{
			printf("Balancing information:\n");
			printf("Total number of Balancing Channels:    %d\n", params.numBalancingRefs);
			printf("Number of 1st gradient coefficients = %d\n", params.numG1Coefs );
			printf("Number of  2nd gradient coefficients = %d\n", params.numG2Coefs );
			printf("Number of  3rd gradient coefficients = %d\n", params.numG3Coefs );
			printf("Number of  3rd+adaptive gradient coefficients = %d\n", params.numG4Coefs );
			printf("1st / 2nd order balancing list:\n");
			for (int j=0; j<params.numG1Coefs; j++)
				printf("%s\n", params.g1List[j]);
			printf("3rd, 3rd+adaptive balancing list:\n");
			for (int j=0; j<params.numG3Coefs; j++)
				printf("%s\n", params.g3List[j]);
			
		}

		for (int i=0; i<params.numChannels; i++)
		{
			printf("______________________________________\n");
			printf("name:              %s\n", params.channel[i].name );
			printf("index:             %d\n", params.channel[i].index );
			printf("sensorType:        %d\n", params.channel[i].sensorType );
			printf("isSensor:          %d\n", params.channel[i].isSensor );
			printf("isReference:       %d\n", params.channel[i].isReference);
			printf("isBalancingRef:    %d\n", params.channel[i].isBalancingRef );
			printf("isEEG:             %d\n", params.channel[i].isEEG );
			printf("gain:              %g\n", params.channel[i].gain );
			printf("properGain:        %g\n", params.channel[i].properGain );
			printf("qGain:             %g\n", params.channel[i].qGain );
			printf("ioGain:            %g\n", params.channel[i].ioGain );  // added in new version of ds_params Sept, 2020
			
			if (params.channel[i].isSensor || params.channel[i].isReference || params.channel[i].isEEG)
			{
				printf("numCoils:          %d\n", params.channel[i].numCoils );
				printf("numTurns:          %d\n", params.channel[i].numTurns );
				printf("coilArea:          %g\n", params.channel[i].coilArea );
				printf("Head coordinates:\n");
				printf("xpos:              %g\n", params.channel[i].xpos );
				printf("ypos:              %g\n", params.channel[i].ypos );
				printf("zpos:              %g\n", params.channel[i].zpos );
				printf("p1x:               %g\n", params.channel[i].p1x );
				printf("p1y:               %g\n", params.channel[i].p1y );
				printf("p1z:               %g\n", params.channel[i].p1z );
				if (params.channel[i].numCoils > 1)
				{
					printf("xpos2:             %g\n", params.channel[i].xpos2 );
					printf("ypos2:             %g\n", params.channel[i].ypos2 );
					printf("zpos2:             %g\n", params.channel[i].zpos2 );
					printf("p2x:               %g\n", params.channel[i].p2x );
					printf("p2y:               %g\n", params.channel[i].p2y );
					printf("p2z:               %g\n", params.channel[i].p2z );
				}
				printf("Dewar coordinates:\n");
				printf("xpos:              %g\n", params.channel[i].xpos_dewar );
				printf("ypos:              %g\n", params.channel[i].ypos_dewar );
				printf("zpos:              %g\n", params.channel[i].zpos_dewar );
				printf("p1x:               %g\n", params.channel[i].p1x_dewar );
				printf("p1y:               %g\n", params.channel[i].p1y_dewar );
				printf("p1z:               %g\n", params.channel[i].p1z_dewar );
				if (params.channel[i].numCoils > 1)
				{
					printf("xpos2:             %g\n", params.channel[i].xpos2_dewar );
					printf("ypos2:             %g\n", params.channel[i].ypos2_dewar );
					printf("zpos2:             %g\n", params.channel[i].zpos2_dewar );
					printf("p2x:               %g\n", params.channel[i].p2x_dewar );
					printf("p2y:               %g\n", params.channel[i].p2y_dewar );
					printf("p2z:               %g\n", params.channel[i].p2z_dewar );
				}
				printf("gradient:          %d\n", params.channel[i].gradient );              
				printf("sphereX:           %g\n", params.channel[i].sphereX );
				printf("sphereY:           %g\n", params.channel[i].sphereY );
				printf("sphereZ:           %g\n", params.channel[i].sphereZ );
				
				if ( includeCoeffs )
				{
					if ( params.numG1Coefs > 0)
					{
						printf("G1 Coefficients:\n");
						for (int j=0; j<params.numG1Coefs; j++)
							printf("%g\n", params.channel[i].g1Coefs[j] );
					}
					if ( params.numG2Coefs > 0)
					{
						printf("G2 Coefficients:\n");
						for (int j=0; j<params.numG2Coefs; j++)
							printf("%g\n", params.channel[i].g2Coefs[j] );
					}
					if ( params.numG3Coefs > 0)
					{
						printf("G3 Coefficients:\n");
						for (int j=0; j<params.numG3Coefs; j++)
							printf("%g\n", params.channel[i].g3Coefs[j] );
					}
					if ( params.numG4Coefs > 0)
					{
						printf("G4 Coefficients:\n");
						for (int j=0; j<params.numG4Coefs; j++)
							printf("%g\n", params.channel[i].g4Coefs[j] );
					}
				}
				
			}
		}
	}
	return (true);
}

// routine to save generic image as a SAM file
// moved here from samUtils since it uses byte swapping

bool saveVolumeAsSvl( char * svlFile, 
					 const vectorCart * voxelList,  
					 double * imageData, 
					 int numVoxels,
					 double xMin, 
					 double xMax, 
					 double yMin, 
					 double yMax, 
					 double zMin, 
					 double zMax, 
					 double stepSize,
					 int imageType)
{
	char			s[256];
	FILE			*fp; // file pointer to .img file 
	
	SAM_HDR			header;

	header.Version = 1;
	sprintf(header.SetName, "None");
	header.NumChans = 150;
	header.NumWeights = 0;
	
	header.XStart = xMin * 0.01;
	header.XEnd = xMax * 0.01;
	header.YStart = yMin * 0.01;
	header.YEnd = yMax * 0.01;
	header.ZStart = zMin * 0.01;
	header.ZEnd = zMax * 0.01;
	
	header.StepSize = stepSize * 0.01;
	header.HPFreq = 0;
	header.LPFreq = 0;
	
	header.MeanNoise = 3.0e-30;
	sprintf(header.MriName, "none");
	header.Nasion[0] = 0;
	header.Nasion[1] = 0;
	header.Nasion[2] = 0;
	header.LeftPA[0] = 0;
	header.LeftPA[1] = 0;
	header.LeftPA[2] = 0;
	header.RightPA[0] = 0;
	header.RightPA[1] = 0;
	header.RightPA[2] = 0;
	header.SAMType = SAM_TYPE_IMAGE;
	header.SAMUnit = imageType;             // actually units rather than type but determines how MRIViewer handles neg. data!!!
	
	char		identString[] = "SAMIMAGE";

	// open file 
	fp = fopen( svlFile, "wb");
	if ( fp == NULL )
	{
		printf("Couldn't open svl file for writing %s \n", svlFile);
		exit (0);
	}
	
	fwrite( identString, sizeof(unsigned char), 8L, fp );
	
	// write as big-endian for CTF software to read...
	swapSvlHeader( &header, HOST_TO_NETWORK );
	
	fwrite( &header, sizeof(SAM_HDR), 1L, fp);
	
	for (int k=0; k<numVoxels; k++)
	{
		double dval = imageData[k];
		imageData[k] = ToFile( dval );
	}
	
	fwrite( imageData, sizeof(double), numVoxels, fp);
	
	// byte swap data back in case calling routine uses it again !
	for (int k=0; k<numVoxels; k++)
	{
		double dval = imageData[k];
		imageData[k] = ToHost( dval );
	}
	
	fclose( fp );				
	
	return (0);
	
}

void swapSvlHeader( SAM_HDR * header, int format )
{
	// offset + size
	if ( format ==  HOST_TO_NETWORK )
	{
		header->Version = ToFile( header->Version );			// 0 + 4
		// SetName -- char array, no swap needed 			// 4 + 256
		header->NumChans = ToFile( header->NumChans );			// 260 + 4
		header->NumWeights = ToFile( header->NumWeights );		// 264 + 4
		// int pad_bytes1, alignment correction				// 268 + 4
		header->XStart = ToFile( header->XStart );			// 272 + 8
		header->XEnd = ToFile( header->XEnd );				// 280 + 8
		header->YStart = ToFile( header->YStart );			// 288 + 8
		header->YEnd = ToFile( header->YEnd );				// 296 + 8
		header->ZStart = ToFile( header->ZStart );			// 304 + 8
		header->ZEnd = ToFile( header->ZEnd );				// 312 + 8
		header->StepSize = ToFile( header->StepSize );			// 320 + 8
		header->HPFreq = ToFile( header->HPFreq );			// 328 + 8
		header->LPFreq = ToFile( header->LPFreq );			// 336 + 8
		header->BWFreq = ToFile( header->BWFreq );			// 344 + 8
		header->MeanNoise = ToFile( header->MeanNoise );		// 352 + 8
		// MriName[256] char array no swap needed			// 360 + 256
		header->Nasion[0] = ToFile( header->Nasion[0] );		// 616 + 4
		header->Nasion[1] = ToFile( header->Nasion[1] );		// 620 + 4
		header->Nasion[2] = ToFile( header->Nasion[2] );		// 624 + 4
		header->RightPA[0] = ToFile( header->RightPA[0] );		// 628 + 4
		header->RightPA[1] = ToFile( header->RightPA[1] );		// 632 + 4
		header->RightPA[2] = ToFile( header->RightPA[2] );		// 636 + 4
		header->LeftPA[0] = ToFile( header->LeftPA[0] );		// 640 + 4
		header->LeftPA[1] = ToFile( header->LeftPA[1] );		// 644 + 4
		header->LeftPA[2] = ToFile( header->LeftPA[2] );		// 648 + 4
		header->SAMType = ToFile( header->SAMType );			// 652 + 4
		header->SAMUnit = ToFile( header->SAMUnit );			// 656 + 4
		//int pad_bytes2 -- end struct on 8 byte boundary 		// 660 +
		//total length = 664
	}
	else
	{
		header->Version = ToHost( header->Version );			// 0 + 4
		// SetName -- char array, no swap needed 			// 4 + 256
		header->NumChans = ToHost( header->NumChans );			// 260 + 4
		header->NumWeights = ToHost( header->NumWeights );		// 264 + 4
		// int pad_bytes1, alignment correction				// 268 + 4
		header->XStart = ToHost( header->XStart );			// 272 + 8
		header->XEnd = ToHost( header->XEnd );				// 280 + 8
		header->YStart = ToHost( header->YStart );			// 288 + 8
		header->YEnd = ToHost( header->YEnd );				// 296 + 8
		header->ZStart = ToHost( header->ZStart );			// 304 + 8
		header->ZEnd = ToHost( header->ZEnd );				// 312 + 8
		header->StepSize = ToHost( header->StepSize );			// 320 + 8
		header->HPFreq = ToHost( header->HPFreq );			// 328 + 8
		header->LPFreq = ToHost( header->LPFreq );			// 336 + 8
		header->BWFreq = ToHost( header->BWFreq );			// 344 + 8
		header->MeanNoise = ToHost( header->MeanNoise );		// 352 + 8
		// MriName[256] char array no swap needed			// 360 + 256
		header->Nasion[0] = ToHost( header->Nasion[0] );		// 616 + 4
		header->Nasion[1] = ToHost( header->Nasion[1] );		// 620 + 4
		header->Nasion[2] = ToHost( header->Nasion[2] );		// 624 + 4
		header->RightPA[0] = ToHost( header->RightPA[0] );		// 628 + 4
		header->RightPA[1] = ToHost( header->RightPA[1] );		// 632 + 4
		header->RightPA[2] = ToHost( header->RightPA[2] );		// 636 + 4
		header->LeftPA[0] = ToHost( header->LeftPA[0] );		// 640 + 4
		header->LeftPA[1] = ToHost( header->LeftPA[1] );		// 644 + 4
		header->LeftPA[2] = ToHost( header->LeftPA[2] );		// 648 + 4
		header->SAMType = ToHost( header->SAMType );			// 652 + 4
		header->SAMUnit = ToHost( header->SAMUnit );			// 656 + 4
		//int pad_bytes2 -- end struct on 8 byte boundary		// 660 + 4
		//total length = 664
	}
}


// returns a 4 x 4 transforrmation rmatrix that converts points fiducial coordinate system to the head based coordinates
// using the CTF Coordinate System convention. Assumes all coords in same units so no scaling is done here

void getCTFHeadTransformation( vectorCart na, vectorCart le, vectorCart re, affine & tmat )
{
	vectorCart 	origin;
	vectorCart 	NAnew;
	vectorCart	LEnew;
    vectorCart  v1;
    vectorCart  v2;
    vectorCart  v3;
    
    affine     rm;
    affine     tm;
	
	//////////////////////////////////////////////////////////////////
	//	Step1. 	Create head coordinate system vectors NAnew and LEnew
	//////////////////////////////////////////////////////////////////
	
	//	head origin is midpoint of LE<->RE
	//
	origin.x = (le.x + re.x) / 2.0;
	origin.y = (le.y + re.y) / 2.0;
	origin.z = (le.z + re.z) / 2.0;
    
    // x-axis is vector from nose to origin
    v1 = subtractVectors( na, origin );
    v1 = unitVector( v1 );
    
    // y-axis is vector from left ear to origin
    // this is then rotated to be orthogonal to x-axis
    v2 = subtractVectors( le, origin );
    v2 = unitVector( v2 );          // rotated y axis
    
    //  z axis
    v3 = vectorCrossProduct( v1, v2 );
	v3 = unitVector( v3 );          // ** correct to unit since angle isn't 90 deg
    
    // then recompute y axis as cross of x and z
    v2 = vectorCrossProduct( v3, v1 );
    
    
    // create transformation matrix
    
    // rotation
    
    rm = affineIdentityMatrix();
    
    rm.m[0][0] = v1.x;
	rm.m[0][1] = v2.x;
	rm.m[0][2] = v3.x;
    
    rm.m[1][0] = v1.y;
	rm.m[1][1] = v2.y;
	rm.m[1][2] = v3.y;
    
    rm.m[2][0] = v1.z;
	rm.m[2][1] = v2.z;
	rm.m[2][2] = v3.z;
    
    // translation
    
    tm = affineIdentityMatrix();
    
    tm.m[3][0] = -origin.x;
	tm.m[3][1] = -origin.y;
	tm.m[3][2] = -origin.z;
    
    tmat = affineXaffine(tm, rm);
    
}

bool updateSensorPositions( char *dsName, vectorCart na, vectorCart le, vectorCart re)
{
    affine     tmat;
    affine     rmat;
    vectorCart  v1;
    vectorCart  v2;
    vectorCart  p1;
    vectorCart  p2;
    
    if ( !readMEGResFile( dsName, DS_dsParams ) )
    {
        return(false);
    }
    
    getCTFHeadTransformation(na, le, re, tmat);
    
    // need rotation only matrix for p-vectors - remove translation
    rmat = tmat;
    rmat.m[3][0] = 0.0;
    rmat.m[3][1] = 0.0;
    rmat.m[3][2] = 0.0;
    
    // modify sensor positions for all MEG channels
    for (int k=0; k<DS_dsParams.numChannels; k++)
    {
		if (DS_dsParams.channel[k].isSensor || (DS_dsParams.channel[k].isReference))
        {
            v1.x = DS_dsParams.channel[k].xpos_dewar;
            v1.y = DS_dsParams.channel[k].ypos_dewar;
            v1.z = DS_dsParams.channel[k].zpos_dewar;
            p1.x = DS_dsParams.channel[k].p1x_dewar;
            p1.y = DS_dsParams.channel[k].p1y_dewar;
            p1.z = DS_dsParams.channel[k].p1z_dewar;
            
            v2 = vectorXaffine( v1, tmat);
            p2 = vectorXaffine( p1, rmat);
            
            DS_dsParams.channel[k].xpos = v2.x;
            DS_dsParams.channel[k].ypos = v2.y;
            DS_dsParams.channel[k].zpos = v2.z;
            
            DS_dsParams.channel[k].p1x = p2.x;
            DS_dsParams.channel[k].p1y = p2.y;
            DS_dsParams.channel[k].p1z = p2.z;
            
            if (DS_dsParams.channel[k].numCoils > 1)
            {
                v1.x = DS_dsParams.channel[k].xpos2_dewar;
                v1.y = DS_dsParams.channel[k].ypos2_dewar;
                v1.z = DS_dsParams.channel[k].zpos2_dewar;
                p1.x = DS_dsParams.channel[k].p2x_dewar;
                p1.y = DS_dsParams.channel[k].p2y_dewar;
                p1.z = DS_dsParams.channel[k].p2z_dewar;
                
                v2 = vectorXaffine( v1, tmat);
                p2 = vectorXaffine( p1, rmat);
                
                DS_dsParams.channel[k].xpos2 = v2.x;
                DS_dsParams.channel[k].ypos2 = v2.y;
                DS_dsParams.channel[k].zpos2 = v2.z;
                
                DS_dsParams.channel[k].p2x = p2.x;
                DS_dsParams.channel[k].p2y = p2.y;
                DS_dsParams.channel[k].p2z = p2.z;
            }
        }
	}
    
    if ( !writeMEGResFile( dsName, DS_dsParams ) )
    {
        printf("error writing .meg4 file\n");
        return(false);
    }
    
    return (true);
}

// D. Cheyne - added Aug 2021 - routines to read and write Marker Files

bool readMarkerFile( char *dsName, markerArray & markerList)
{
	char			markerFile[256];
	char			markerName[32];
	char			tStr[64];
	char			inStr[64];
	
	int				numMarkers = 0;
	
	FILE			*fp;
	
	// get num markers to create struct array
	
	sprintf(markerFile, "%s%sMarkerFile.mrk", dsName, FILE_SEPARATOR );
	
	if ( ( fp = fopen( markerFile, "r") ) == NULL )
	{
		printf("couldn't open Marker File [%s]\n", markerFile);
		return(false);
	}
	
	while (!feof(fp))
	{
		charPtr = fgets(inStr, 256, fp);
		if (strncmp(inStr,"NAME:", 5) == 0)
		{
			numMarkers++;
		}
	}
	
	rewind(fp);
	
	if (numMarkers > MAX_MARKERS)
	{
		printf("exceeded max. number of markers (%d)", MAX_MARKERS);
		return(false);
	}
	
	printf("reading %d markers from Marker File [%s]\n", numMarkers, markerFile);
	markerList.numMarkers = numMarkers;
	
	int markerNo = 0;
	while (!feof(fp))
	{
		charPtr = fgets(inStr, 256, fp);
		if (strncmp(inStr,"NAME:", 5) == 0)
		{
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s", markerList.markers[markerNo].markerName);
		}
		else if (strncmp(inStr,"COMMENT:", 8) == 0)
		{
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s", markerList.markers[markerNo].markerComment);
		}
		else if (strncmp(inStr,"COLOR:", 6) == 0)
		{
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%s", markerList.markers[markerNo].markerColor);
		}
		else if (strncmp(inStr,"CLASSID:", 8) == 0)
		{
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%d", &(markerList.markers[markerNo]).markerClassID);
		}
		else if (strncmp(inStr,"NUMBER OF SAMPLES:", 18) == 0)
		{
			charPtr = fgets(inStr, 256, fp);
			sscanf(inStr, "%d", &(markerList.markers[markerNo]).numSamples);
		}
		else if ( (strncmp(inStr,"TRIAL NUMBER", 12) == 0) )
		{
			if (markerList.markers[markerNo].numSamples > MAX_MARKER_SAMPLES)
			{
				printf("exceeded max. number of samples (%d)", MAX_MARKER_SAMPLES);
				return(false);
			}
			for (int k=0; k<markerList.markers[markerNo].numSamples; k++)
			{
				charPtr = fgets(inStr, 256, fp);
				sscanf(inStr, "%d %lf", &(markerList.markers[markerNo]).trial[k], &(markerList.markers[markerNo]).latency[k]);
			}
			markerNo++;  // go to next marker
		}
	}
	
	fclose(fp);
	
	return (true);
}

bool writeMarkerFile( char *dsName, const markerArray & markerList)
{
	char			markerFile[256];
	char			markerName[256];
	char			tStr[256];
	char			inStr[256];
	int				numMarkers = 0;
	
	FILE			*fp;
	
	// assume calling routine creates backup if overwriting an original dataset.
	sprintf(markerFile, "%s%sMarkerFile.mrk", dsName, FILE_SEPARATOR );
	if ( ( fp = fopen( markerFile, "wa") ) == NULL )
	{
		printf("couldn't create file [%s]\n", markerFile);
		return(false);
	}
	
	fprintf(fp,"PATH OF DATASET:\n");
	fprintf(fp,"%s\n", dsName);
	fprintf(fp,"\n");
	fprintf(fp,"\n");
	
	fprintf(fp,"NUMBER OF MARKERS:\n");
	fprintf(fp,"%d\n", markerList.numMarkers);
	fprintf(fp,"\n");
	fprintf(fp,"\n");
	
	for (int k=0; k<markerList.numMarkers; k++)
	{
		fprintf(fp,"CLASSGROUPID:\n");
		fprintf(fp,"+3\n");
		fprintf(fp,"NAME:\n");
		fprintf(fp,"%s\n", markerList.markers[k].markerName);
		fprintf(fp,"COMMENT:\n");
		fprintf(fp,"%s\n", markerList.markers[k].markerComment);
		fprintf(fp,"COLOR:\n");
		fprintf(fp,"%s\n", markerList.markers[k].markerColor);
		fprintf(fp,"EDITABLE:\n");
		fprintf(fp,"No\n");
		fprintf(fp,"CLASSID:\n");
		fprintf(fp,"%d\n", markerList.markers[k].markerClassID);
		fprintf(fp,"NUMBER OF SAMPLES:\n");
		fprintf(fp,"%d\n", markerList.markers[k].numSamples);
		fprintf(fp,"LIST OF SAMPLES:\n");
		fprintf(fp,"TRIAL NUMBER\t\tTIME FROM SYNC POINT (in seconds):\n");
		for (int j=0; j<markerList.markers[k].numSamples; j++)
			fprintf(fp,"        %d          %+.10f\n", markerList.markers[k].trial[j], markerList.markers[k].latency[j]);
		fprintf(fp,"\n");
		fprintf(fp,"\n");
	}
	fprintf(fp,"\n");
	fprintf(fp,"\n");
	
	fclose(fp);
	
	return (true);
	
}




