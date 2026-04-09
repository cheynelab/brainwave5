/////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//		bw_makeCrossTalkImages
//
//		C-mex function to make CTF and PSF images
//      derived from makeBeamformer
// 
//
//		(c) Douglas O. Cheyne, 2025  All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "mex.h"

#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#if defined _WIN64 || defined _WIN32
	#include <pthread.h>//pthread library for windows, added by zhengkai
#endif

#include "../src/meglib/headers/datasetUtils.h"
#include "../src/meglib/headers/BWFilter.h"
#include "../src/meglib/headers/path.h"
#include "../src/meglib/headers/bwlib.h"
#include "bw_version.h"

double			**imageData; 
double			**covArray;
double			**icovArray;
vectorCart		*voxelList;
vectorCart		*normalList;

char			**fileList;
ds_params		dsParams;

extern "C" 
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    double			*dataPtr;
    char			*dsName;
    char			*covDsName;
    char			*hdmFile;
    char			*voxFileName;
    
    int				buflen;
    int				status;
    unsigned int	m;
    unsigned int	n;
    char			msg[256];
    char			filename[4096];
    char            filename1[4096];
    char            filename2[4096];
    
    char			savename[8192];
    char			imageFileBaseName[2048];
    char            imageFileBaseName2[8192];
    char			analysisDir[256];
    char			cmd[4096];
    char			s[256];
    
    double			*val;
    FILE			*fp;
    
    // makeVS params...
    
    int				numVoxels;
    int             numCovSensors;
    
    double          highPass;
    double          lowPass;
    
    double			minTime;
    double			maxTime;
    
    double			wStart;
    double			wEnd;
    
    double			regularization = 0.0;
    
    bool			nonRectified = false;
    
    bool			useHdmFile = false;
    bool			useVoxFile = false;
    bool			useVoxNormals = true;
    
    bool			useReverseFilter = true;
    
    int             outputFormat = 0;  // 0 = CIVET *.txt, 2 = Freesurfer overlay *.w
    
    double			xMin;
    double			xMax;
    double			yMin;
    double			yMax;
    double			zMin;
    double			zMax;
    double			stepSize;
    
    double			sphereX = 0.0;
    double			sphereY = 0.0;
    double			sphereZ = 5.0;
    
    double          voxelX = 0.0;
    double          voxelY = 0.0;
    double          voxelZ = 0.0;
    
    int             voxelIndex = 0;         // index of target voxel in voxel list
    
    bf_params		bparams;
    filter_params 	fparams;
    
    
    /* Check for proper number of arguments */
    int n_inputs = 18;
    int n_outputs = 1;
    mexPrintf("bw_makeCrossTalkImages ver. %.1f (%s) (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", BW_VERSION, BW_BUILD_DATE);
    if ( nlhs != n_outputs | nrhs != n_inputs)
    {
        mexPrintf("\nincorrect number of input or output arguments for bw_makeEventRelated  ...\n");
        mexPrintf("\nCalling syntax:\n");
        mexPrintf("[fileNames] = bw_makeCrossTalkImages(datasetName, covarianceDsName, hdmFileName, useHdmFile, filter, boundingBox, stepSize, \n");
        mexPrintf("                   covWindow, voxelFileName, useVoxFile, useVoxNormals, baselineWindow, useBaselineWindow, sphere, noiseRMS, regularization, \n");
        mexPrintf("                   useReverseFilter, targetVoxel )\n");
        mexPrintf("\n returns: name of the .list file and an array of names of files saved to disk. \n");
        return;
    }
    
    ///////////////////////////////////
    // get datasest name
    if (mxIsChar(prhs[0]) != 1)
        mexErrMsgTxt("Input [0] must be a string for dataset name.");
    if (mxGetM(prhs[0]) != 1)
        mexErrMsgTxt("Input [0] must be a row vector.");
    // Get the length of the input string.
    buflen = (mxGetM(prhs[0]) * mxGetN(prhs[0])) + 1;
    dsName = (char *)mxCalloc(buflen, sizeof(char));
    status = mxGetString(prhs[0], dsName, buflen);  	// Copy the string into a C string
    if (status != 0)
        mexWarnMsgTxt("Not enough space. String is truncated.");
    
    ///////////////////////////////////
    // get covariance datasest name - may be same as dsName
    if (mxIsChar(prhs[1]) != 1)
        mexErrMsgTxt("Input [1] must be a string for covariance dataset name.");
    if (mxGetM(prhs[1]) != 1)
        mexErrMsgTxt("Input [1] must be a row vector.");
    // Get the length of the input string.
    buflen = (mxGetM(prhs[1]) * mxGetN(prhs[1])) + 1;
    covDsName = (char *)mxCalloc(buflen, sizeof(char));
    status = mxGetString(prhs[1], covDsName, buflen);  	// Copy the string into a C string
    if (status != 0)
        mexWarnMsgTxt("Not enough space. String is truncated.");
    
    ///////////////////////////////////
    // get headModel file name
    if (mxIsChar(prhs[2]) != 1)
        mexErrMsgTxt("Input [2] must be a string for head model name.");
    // Get the length of the input string.
    buflen = (mxGetM(prhs[2]) * mxGetN(prhs[2])) + 1;
    if (buflen < 1)
    {
        sprintf(msg, "Must pass valid hdm File name.");
        mexWarnMsgTxt(msg);
        mxFree(dsName);
        return;
    }
    else
    {
        hdmFile = (char *)mxCalloc(buflen, sizeof(char));
        status = mxGetString(prhs[2], hdmFile, buflen);  	// Copy the string into a C string
    }
    if (status != 0)
        mexWarnMsgTxt("Not enough space. String is truncated.");
    
    val = mxGetPr(prhs[3]);
    useHdmFile = (int)*val;
    
    if (mxGetM(prhs[4]) != 1 || mxGetN(prhs[4]) != 2)
        mexErrMsgTxt("Input [4] must be a row vector [hipass lowpass].");
    dataPtr = mxGetPr(prhs[4]);
    highPass = dataPtr[0];
    lowPass = dataPtr[1];
    
    if (mxGetM(prhs[5]) != 1 || mxGetN(prhs[5]) != 6)
        mexErrMsgTxt("Input [5] must be row vector [xmin xmax ymin ymax zmin zmax]");
    dataPtr = mxGetPr(prhs[5]);
    xMin = dataPtr[0];
    xMax = dataPtr[1];
    yMin = dataPtr[2];
    yMax = dataPtr[3];
    zMin = dataPtr[4];
    zMax = dataPtr[5];
    
    val = mxGetPr(prhs[6]);
    stepSize = *val;
    
    if (mxGetM(prhs[7]) != 1 || mxGetN(prhs[7]) != 2)
        mexErrMsgTxt("Input [7] must be a row vector [wStart wStart].");
    dataPtr = mxGetPr(prhs[7]);
    wStart = dataPtr[0];
    wEnd = dataPtr[1];
    
    ///////////////////////////////////
    // get voxFile name
    if (mxIsChar(prhs[8]) != 1)
        mexErrMsgTxt("Input [8] must be a string for voxfile name.");
    if (mxGetM(prhs[8]) != 1)
        mexErrMsgTxt("Input [8] must be a row vector.");
    if (mxGetN(prhs[8]) > 0)
    {
        // Get the length of the input string.
        buflen = (mxGetM(prhs[8]) * mxGetN(prhs[8])) + 1;
        voxFileName = (char *)mxCalloc(buflen, sizeof(char));
        status = mxGetString(prhs[8], voxFileName, buflen);  	// Copy the string into a C string
        if (status != 0)
            mexWarnMsgTxt("Not enough space. String is truncated.");
    }
    
    val = mxGetPr(prhs[9]);
    useVoxFile = (int)*val;
    
    val = mxGetPr(prhs[10]);
    useVoxNormals = (int)*val;
    
    if (mxGetM(prhs[11]) != 1 || mxGetN(prhs[11]) != 2)
        mexErrMsgTxt("Input [11] must be a row vector [bStart bStart].");
    dataPtr = mxGetPr(prhs[11]);
    bparams.baselineWindowStart = dataPtr[0];
    bparams.baselineWindowEnd = dataPtr[1];
    
    val = mxGetPr(prhs[12]);
    bparams.baselined = (int)*val;
    
    if (mxGetM(prhs[13]) != 1 || mxGetN(prhs[13]) != 3)
        mexErrMsgTxt("Input [13] must be a row vector [sphereX sphereY sphereZ].");
    dataPtr = mxGetPr(prhs[13]);
    sphereX = dataPtr[0];
    sphereY = dataPtr[1];
    sphereZ = dataPtr[2];
    
    val = mxGetPr(prhs[14]);
    bparams.noiseRMS = *val;
    bparams.normalized = true;
    
    val = mxGetPr(prhs[15]);
    regularization = *val;
    
    val = mxGetPr(prhs[16]);
    useReverseFilter = (int)*val;
    
    if (mxGetM(prhs[17]) != 1 || mxGetN(prhs[17]) != 3)
        mexErrMsgTxt("Input [17] must be a row vector [voxelX voxelY voxelZ].");
    dataPtr = mxGetPr(prhs[17]);
    voxelX = dataPtr[0];
    voxelY = dataPtr[1];
    voxelZ = dataPtr[2];
    
    
    ////////////////////////////////////////////////
    // setup directory paths and filenames
    ////////////////////////////////////////////////
    
    //added file separator for windows, added by zhengkai
    
    sprintf(analysisDir, "%s%sANALYSIS", dsName,FILE_SEPARATOR);
    
    if ( ( fp = fopen(analysisDir, "r") ) == NULL )
    {
        mexPrintf ("Creating new ANALYSIS subdirectory in %s\n", dsName);
        sprintf (cmd, "mkdir %s", analysisDir);
        int errNo = system (cmd);
    }
    else
        fclose(fp);
    
    
    // ** new - check covariance data file for data range error
    // ** also add check that sensor number agrees
    
    if ( !readMEGResFile( covDsName, dsParams) )
    {
        mexPrintf("Error reading res4 file for %s/n", covDsName);
        return;
    }
    minTime = dsParams.epochMinTime;
    maxTime = dsParams.epochMaxTime;
    numCovSensors = dsParams.numSensors;
    
    if (wStart < minTime || wEnd > maxTime)
    {
        mexPrintf("Covariance window values (%g to %g seconds) exceeds data length (%g to %g seconds)\n", wStart, wEnd, minTime, maxTime);
        return;
    }
    
    if ( !readMEGResFile( dsName, dsParams) )
    {
        mexPrintf("Error reading res4 file for %s/n", dsName);
        return;
    }
    
    mexPrintf("dataset:  %s, (%d trials, %d samples, %d sensors, epoch time = %g to %g s)\n",
              dsName, dsParams.numTrials, dsParams.numSamples, dsParams.numSensors, dsParams.epochMinTime, dsParams.epochMaxTime);
    mexEvalString("drawnow");
    
    if (dsParams.numSensors != numCovSensors)
    {
        mexPrintf("Covariance dataset and image dataset have different numbers of sensors...\n");
        return;
    }
    
    if ( !init_dsParams( dsParams, &sphereX, &sphereY, &sphereZ, hdmFile, useHdmFile) )
    {
        mexErrMsgTxt("Error initializing dsParams and head model\n");
        return;
    }
    
    bparams.type = BF_TYPE_OPTIMIZED;
    
    bparams.sphereX = sphereX;
    bparams.sphereY = sphereY;
    bparams.sphereZ = sphereZ;
    
    if (useHdmFile)
        mexPrintf("Using head model file %s (mean sphere = %g %g %g)\n", hdmFile,  bparams.sphereX, bparams.sphereY, bparams.sphereZ);
    else
        mexPrintf("Using single sphere %g %g %g\n",  sphereX, sphereY, sphereZ);
    
    if (bparams.baselined)
        mexPrintf("Using baseline window for average (%g to %g s)\n",  bparams.baselineWindowStart, bparams.baselineWindowEnd);
    
    
    mexEvalString("drawnow");
    
    // setup filter
    if ( highPass == 0 && lowPass == 0)
    {
        bparams.hiPass = dsParams.highPass;		// still need to know bandpass for covariance files etc..
        bparams.lowPass = dsParams.lowPass;
        fparams.hc = bparams.lowPass;			// fparams used to get name for covariance file!
        fparams.lc = bparams.hiPass;
        fparams.enable = false;
        printf("**No filter specified. Using bandpass of dataset (%g to %g Hz)\n", bparams.hiPass, bparams.lowPass);
    }
    else
    {
        bparams.hiPass = highPass;
        bparams.lowPass = lowPass;
        fparams.enable = true;
        if ( bparams.hiPass == 0.0 )
            fparams.type = BW_LOWPASS;
        else
            fparams.type = BW_BANDPASS;
        fparams.bidirectional = useReverseFilter;
        fparams.hc = bparams.lowPass;
        fparams.lc = bparams.hiPass;
        fparams.fs = dsParams.sampleRate;
        fparams.order = 4;	//
        fparams.ncoeff = 0;				// init filter
        
        if (build_filter (&fparams) == -1)
        {
            mexPrintf("Could not build filter.  Exiting\n");
            return;
        }
        
        if (fparams.bidirectional)
            mexPrintf("Applying filter from %g to %g Hz (bidirectional)\n", bparams.hiPass, bparams.lowPass);
        else
            mexPrintf("Applying filter from %g to %g Hz (non-bidirectional)\n", bparams.hiPass, bparams.lowPass);
        
        
    }
    mexEvalString("drawnow");
    
    // generate covariance arrays for primary sensors...
    //
    covArray = (double **)malloc( sizeof(double *) * dsParams.numSensors );
    if (covArray == NULL)
    {
        mexPrintf("memory allocation failed for covariance array");
        return;
    }
    for (int i = 0; i < dsParams.numSensors; i++)
    {
        covArray[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
        if ( covArray[i] == NULL)
        {
            mexPrintf( "memory allocation failed for covariance array" );
            return;
        }
    }
    icovArray = (double **)malloc( sizeof(double *) * dsParams.numSensors );
    if (icovArray == NULL)
    {
        mexPrintf("memory allocation failed for inverse covariance array");
        return;
    }
    for (int i = 0; i < dsParams.numSensors; i++)
    {
        icovArray[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
        if ( icovArray[i] == NULL)
        {
            mexPrintf( "memory allocation failed for covariance array" );
            return;
        }
    }
    
    mexEvalString("drawnow");
    
    
    ///////////////////
    // if in .svl coordinates initialize source space grid
    
    double x;
    double y;
    double z;
    int index = 0;
    
    if (useVoxFile)
    {
        char *charsRead;
        
        fp = fopen(voxFileName, "r");
        if (fp == NULL)
        {
            mexPrintf("Couldn't open voxfile  %s\n", voxFileName);
            return;
        }
        charsRead = fgets(s, 256, fp);
        sscanf(s, "%d", &numVoxels);
        
        if (useVoxNormals)
            mexPrintf("Computing images for %d voxels specified in %s (with cortical constraints) \n", numVoxels, voxFileName);
        else
            mexPrintf("Computing images for %d voxels specified in %s (without cortical constraints) \n", numVoxels, voxFileName);
        
        voxelList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
        if ( voxelList == NULL)
        {
            mexPrintf("Could not allocate memory for voxel lists\n");
            return;
        }
        
        normalList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
        if ( normalList == NULL)
        {
            mexPrintf("Could not allocate memory for normal lists\n");
            return;
        }
        
        for (int i=0; i < numVoxels; i++)
        {
            charsRead = fgets(s, 256, fp);
            sscanf(s, "%lf %lf %lf %lf %lf %lf",
                   &voxelList[i].x, &voxelList[i].y, &voxelList[i].z,
                   &normalList[i].x, &normalList[i].y, &normalList[i].z);
        }
        
        fclose(fp);
    }
    else
    {
        // create .svl volume using passed bounding box
        double dx = (xMax - xMin) / stepSize;
        double dy = (yMax - yMin) / stepSize;
        double dz = (zMax - zMin) / stepSize;
        
        // add 1 voxel for zero crossing i.e., sets range to -10 to -10 inclusive
        int xVoxels = (int)dx + 1;
        int yVoxels = (int)dy + 1;
        int zVoxels = (int)dz + 1;
        
        // get true range based on number of voxels
        xMax = xMin + ( (xVoxels-1)*stepSize);
        yMax = yMin + ( (yVoxels-1)*stepSize);
        zMax = zMin + ( (zVoxels-1)*stepSize);
        
        numVoxels = xVoxels * zVoxels * yVoxels;
        voxelList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
        
        if ( voxelList == NULL)
        {
            mexPrintf("Could not allocate memory for voxel lists\n");
            return;
        }
        
        normalList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
        if ( normalList == NULL)
        {
            mexPrintf("Could not allocate memory for voxel lists\n");
            return;
        }

        index = 0;
        for (int i=0; i< xVoxels; i++)
        {
            for (int j=0; j< yVoxels; j++)
            {
                for (int k=0; k< zVoxels; k++)
                {
                    // voxel location relative to coord. system origin
                    x = xMin + (i * stepSize);
                    y = yMin + (j * stepSize);
                    z = zMin + (k * stepSize);
                    
                    voxelList[index].x = x;
                    voxelList[index].y = y;
                    voxelList[index].z = z;
                    
                    normalList[index].x = 1;
                    normalList[index].y = 0;
                    normalList[index].z = 0;
                    index++;
                }
            }
        }
        
        mexPrintf("Using regular reconstruction grid in MEG coordinates with bounding box = [x = %g %g, y= %g %g, z= %g %g], resolution [%g cm] (%d voxels)\n",
               xMin, xMax, yMin, yMax, zMin, zMax, stepSize, numVoxels );
    }

 
    // find voxel index of voxel closest to the target voxel
     
    double closest = 100000.0;
    double dist = 0.0;
    index = 0;
    for (int k=0; k<numVoxels; k++ )
    {
        x = voxelList[k].x;
        y = voxelList[k].y;
        z = voxelList[k].z;
        
        // save index of voxel closest to passed target voxel coordinates
        dist = sqrt( (x-voxelX)*(x-voxelX) + (y-voxelY)*(y-voxelY) + (z-voxelZ)*(z-voxelZ) );
        if (dist < closest)
        {
            closest = dist;
            voxelIndex = index;
        }
        index++;
    }

    mexPrintf("Found target Voxel = [x = %g, y= %g z= %g], voxel index = %d (%g cm from target)\n", voxelX, voxelY, voxelZ, voxelIndex, closest);
    
	mexEvalString("drawnow");
	
	////////////////////////////////////////////////////////////////////////
	// set up file names for writing data...
	////////////////////////////////////////////////////////////////////////
	// filename always start with this...
	sprintf(imageFileBaseName, "image,cw_%g_%g", wStart, wEnd);
	
	sprintf(imageFileBaseName, "%s,%g-%gHz", imageFileBaseName, bparams.hiPass, bparams.lowPass);
 	////////////////////////////////////////////////////////////////////////
	
	char addName[256];
	if (useVoxFile)
	{
		removeFilePath(voxFileName, s);
		removeDotExtension(s, addName);
		sprintf(imageFileBaseName, "%s,_vox_%s",imageFileBaseName, addName);
		if (!useVoxNormals)
			sprintf(imageFileBaseName,"%s_NC", imageFileBaseName);
	}
	if ( strcmp(dsName,covDsName) )
	{
		removeFilePath(covDsName, s);
		removeDotExtension(s, addName);
		sprintf(imageFileBaseName, "%s,cDs_%s",imageFileBaseName, addName);
	}
	if (regularization > 0.0)
		sprintf(imageFileBaseName,"%s,reg=%g", imageFileBaseName, regularization);


	mexPrintf("computing %d by %d covariance matrix (BW %g to %g Hz) for window %g %g s (reg. = %g) from dataset %s\n",
			  dsParams.numSensors, dsParams.numSensors, bparams.hiPass, bparams.lowPass, wStart, wEnd, regularization, covDsName);
	mexEvalString("drawnow");

	// get covariance... - need to remove anglewindow args from library function...
	computeCovarianceMatrices(covArray, icovArray, dsParams.numSensors, covDsName, fparams, wStart, wEnd, wStart, wEnd, false, regularization);
	
	// allocate memory for all images...
	imageData = (double **)malloc( sizeof(double *) * 2 );
	if (imageData == NULL)
	{
		mexPrintf("memory allocation failed for imageData array");
		return;
	}
    
	for (int i = 0; i < 2; i++)
	{
		imageData[i] = (double *)malloc( sizeof(double) * numVoxels );
		if ( imageData[i] == NULL)
		{
			mexPrintf( "memory allocation failed for imageData array" );
			return;
		}
	}

    // create character array of image filenames
    fileList = (char **)malloc(sizeof(char *) * 2);
    for (int i=0; i<2; i++)
    {
        fileList[i] = (char *)malloc(sizeof(char) * 256);
        if (fileList[i] == NULL)
        {
            mexPrintf( "memory allocation failed for fileList array" );
            return;
        }
    }
    mexPrintf("computing cross-talk and point-spread function images from dataset %s\n", dsName);
    mexEvalString("drawnow");
    
    if ( !computeCrossTalk(imageData, dsName, dsParams, bparams, covArray, icovArray, numVoxels,
                           voxelList, normalList, voxelIndex) )
    {
        mexPrintf( "error returned from computeCrossTalk\n" );
        return;
    }
    
    // *** test code set target voxel to 1.0 all other voxels to zero.
//
//    for (int i=0; i<numVoxels; i++)
//    {
//        imageData[0][i] = 0.0;
//        imageData[1][i] = 0.0;
//    }
//    imageData[0][voxelIndex] = 1.0;
//    imageData[1][voxelIndex] = 1.0;
    
#if _WIN32||WIN64
        sprintf(filename, "%s\\%s_voxel_%.2f_%.2f_%.2f", analysisDir, imageFileBaseName, voxelX, voxelY, voxelZ);
#else
        sprintf(filename, "%s/%s_voxel_%.2f_%.2f_%.2f", analysisDir, imageFileBaseName, voxelX, voxelY, voxelZ);
#endif
    
    if (useVoxFile)
    {
        sprintf(savename, "%s_CTF.txt", filename);
        mexPrintf("Saving cross-talk function images in ASCII text file %s\n", savename);
        sprintf(fileList[0],"%s",savename);
        
        fp = fopen(savename, "w");
        if ( fp == NULL)
        {
            mexPrintf("Couldn't open ASCII file %s\n", savename);
            return;
        }
        for (int voxel=0; voxel<numVoxels; voxel++)
            fprintf(fp, "%g\n",imageData[0][voxel]);
        fclose(fp);
        
        sprintf(savename, "%s_PSF.txt", filename);
        mexPrintf("Saving point-spread function images in ASCII text file %s\n", savename);
        sprintf(fileList[1],"%s",savename);
        
        fp = fopen(savename, "w");
        if ( fp == NULL)
        {
            mexPrintf("Couldn't open ASCII file %s\n", savename);
            return;
        }
        for (int voxel=0; voxel<numVoxels; voxel++)
            fprintf(fp, "%g\n",imageData[1][voxel]);
        fclose(fp);
        
    }
    else
    {
        sprintf(savename, "%s_CTF.svl", filename);
        mexPrintf("Saving cross-talk function images in as %s\n", savename);
        saveVolumeAsSvl(savename, voxelList, imageData[0], numVoxels, xMin, xMax, yMin, yMax, zMin, zMax, stepSize, SAM_UNIT_SPMZ);
        sprintf(fileList[0],"%s",savename);
        
        sprintf(savename, "%s_PSF.svl", filename);
        mexPrintf("Saving point-spread function images in as %s\n", savename);
        saveVolumeAsSvl(savename, voxelList, imageData[1], numVoxels, xMin, xMax, yMin, yMax, zMin, zMax, stepSize, SAM_UNIT_SPMZ);
        sprintf(fileList[1],"%s",savename);
    }
    
	mexEvalString("drawnow");
    
    
    plhs[0] = mxCreateCharMatrixFromStrings(2, (const char **)fileList);
	
	///////////////////////////////////
    // change for Version 2.5 - always save .vox file...
	// 
	
#if _WIN32||WIN64
	sprintf(filename,"%s\\%s.vox", analysisDir, imageFileBaseName);
#else
	sprintf(filename,"%s/%s.vox", analysisDir, imageFileBaseName);
#endif
		
    mexPrintf("writing vox file with computed orientations to %s\n", filename);
    
    fp = fopen(filename, "w");
    if ( fp == NULL)
    {
        mexPrintf("Couldn't open voxel file %s\n", filename);
        return;
    }
    
    fprintf(fp, "%d\n", numVoxels);
    for (int i=0; i< numVoxels; i++)
    {
        fprintf(fp, "%.2f\t%.2f\t%.2f\t%.3f\t%.3f\t%.3f\n", 
                voxelList[i].x, voxelList[i].y, voxelList[i].z,
                normalList[i].x, normalList[i].y, normalList[i].z);
    }
    fclose(fp);
	
	///////////////////////////////////
	// free temporary arrays for this routine

	for (int i = 0; i < 2; i++)
		free(imageData[i]);
	free(imageData);
	
	for (int i = 0; i < dsParams.numSensors; i++)
		free(covArray[i]);
	free(covArray);
	
	for (int i = 0; i < dsParams.numSensors; i++)
		free(icovArray[i]);
	free(icovArray);	
	
    for (int i=0; i <2; i++)
        free(fileList[i]);
    free(fileList);
    
	free(voxelList);
	free(normalList);
	
	mxFree(dsName);
	mxFree(hdmFile);
	
	return;
         
}
    
}


