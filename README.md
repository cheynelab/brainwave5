# BrainWave5 QuickStart Guide

### (version 5.3, April 2026 build)

---

### Welcome to the latest version of Brainwave

BrainWave is a Matlab based graphical user interface (GUI) for the computation of beamformer source images and waveforms from magnetoencephalography (MEG) data. It utilizes an integrated viewer for visualizing 4-dimensional image sequences and overlay of images on cortical surfaces, with simple point-and click waveform and time-frequency plotting. BrainWave can also be used to perform MRI based spatial normalization and group analysis of source images using Freesurfer.

BrainWave was developed by Douglas Cheyne at the Hospital for Sick Children, with support from the Canadian Institutes of Health Research (CIHR),  the Natural Sciences and Engineering Research Council (NSERC) of Canada.  Additional contributors (in alphabetical order):  Sonya Bells, Andreea Bostan, Wilken Chau, Zhengkai Chen, Teresa Cheung, Paul Ferrari, Tony Herdman, Cecilia Jobst, Marc Lalancette, Brad Moores, Merron Woodbury, Maher Quraan, Natascha van Lieshout. Wavelet transform adapted from Ole Jensen's 4DToolbox. 

A number of 3rd party matlab toolboxes (located in brainwave/external) are included for file conversions and additional processing, including NIfTI package from Jimmy Shen, Rotman Research Institute. Talairach database from http://www.talairach.org. DICOM to NIfTI conversion using Dicm2nii by Xiangrui Li. 2011, MNE-matlab toolbox from Matti Hamalainen and Alexandre Gramfort for FIF file importing. YokogawaMEGReaderToolbox_1.4 Copyright (c) 2011 YOKOGAWA Electric Corporation. Topoplot routines from Andy Spydell & Colin Humphries, CNL / Salk Institute

BrainWave logo by Natasha van Lieshout. 

---

### Copyright

BrainWave5 is provided free of charge. You can redistribute it and/or modify it under the terms of the GNU General Public License. Unauthorised copying and distribution of 3rd party toolboxes included with BrainWave that are not explicitly covered by the GPL is not allowed.


**This software is NOT APPROVED FOR CLINICAL USE and comes with NO WARRANTY.**

The following publications should be cited when using this toolbox:

Jobst S., Ferrari P., Isabella S., Cheyne D. (2018) BrainWave: A MATLAB toolbox for beamformer source analysis of MEG data. Frontiers in Neuroscience 12: 587.


Cheyne D., Bakhtazad L. and Gaetz W. (2006) Spatiotemporal Mapping of Cortical Activity Accompanying Voluntary Movements Using an Event-Related Beamforming Approach. Human Brain Mapping 27: 213-229. 


Robinson, S. and Vrba J. (1999) Functional neuroimaging by Synthetic Aperture Magnetometry. In: T. Yoshimine, M. Kotani, S. Kuriki, H. Karibe, N Nakasato (Eds). Recent Advances in Biomagnetism. Tohoku University Press, Sendai p 302-305.


Fischl B. FreeSurfer. NeuroImage. 2012;62(2):774–81. 

* **Note: BrainWave5 is major update and not compatible with BrainWave versions 4.x or earlier.**

---

## Installing the software

### Dependancies for BrainWave5

* **Hardware Requirements:** 

BrainWave5 runs on both Linux and MacOS operating systems. BrainWave uses compiled C-mex functions that run natively on Intel and Silicon processors and multithreading to decrease computation times (16GB memory or greater recommended). 

For co-registration of beamformer source images with structural MRI images and spatial normalization to the MNI template for group averaging, you will need to install Freesurfer (© 2026 Laboratories for Computational Neuroimaging). While Freesurfer is not needed to run BrainWave5 it is recommended to have a local installation of Freesurfer for more seamless processing of MRI data. 

You can download and install FreeSurfer from the Freesurfer website [here](https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall).It is recommended to use default locations for Freesurfer (/Applications or /usr/local/bin). Ensure all environments are set for use in MATLAB as per instruction on the FreeSurfer website.

* **Warning:** Versions PRIOR to version 8 are required to ensure correct MNI coregistration. 


### Installing BrainWave5

Download and unzip the latest version of "Brainwave5" [available here](https://github.com/cheynelab/brainwave5) to a local directory.
Add this directory to your Matlab path and/or your Matlab startup.m file.

* Note:  On **MacOS** you may see the error **"....mexmaca64” cannot be opened because the developer cannot be verified"** the first time you run Brainwave. In this case, use the MacOS Terminal Application to open a command line window and execute the following two commands.

> *sudo xattr -r -d com.apple.quarantine "pathToBrainWave"*

>(You will be prompted to enter the administrator password)


### Running BrainWave5

To start Brainwave type:

> brainwave

This will open the Brainwave main menu. All brainwave functions can be accessed through this menu. 


* TIP: while running BrainWave GUI detailed information on computations and processes (including reading and saving of files) are output to the Matlab Command Window. It is advised to keep this window open and visible while running BrainWave to monitor for errors or warnings. 


---


## Organizing your MEG data for BrainWave

BrainWave works with the CTF dataset format (dataset_name.ds) in which each dataset is a directory containing multiple files specifying the MEG header, MEG data and associated files for one data collection. All output from Brainwave (source images etc) will be saved in an ANALYSIS subdirectory in this directory. Never move the ANALYSIS directory to another location.
* *Although BrainWave will work somewhat interchangeably with CTF formats not all features of CTF software are supported.*

Each dataset filename for a given participant must begin with a unique subjectID alphanumeric string followed by an underscore (e.g., 003_goTrials_correct.ds or SID3_goTrials_correct.ds). Any characters after the first underscore are ignored and do not have to match across or within participants.  

For group averaging all datasets must be located in the same directory along with their respective MRI folders. (MRI folders will be created by BrainWave when importing MRI data).  
  
For group analysis of multiple participants create a dedicated study directory and place all participants and conditions in that directory (not in subdirectories).  

* Example:
>Go-NoGo_study/
>>001_goTrials_correct.ds  
>>001_noGoTrials_correct.ds  
>>001_MRI  ----these folders will be created by BrainWave----  
>>002_goTrials_correct.ds  
>>002_noGoTrials_correct.ds  
>>002_MRI  
>>.  
>>etc

* **IMPORTANT:** Brainwave uses relative directory paths to find files. Always set your current working directory in Matlab to the current study directory containing any datasets that you are processing. 

---

## Importing and Preprocessing MRI

### Using Freesurfer to import participant MRI structural scans with basic brain surface extraction.  

#### You must first import the MRI data into a BrainWave format. 
1. Click on Import MRI and select an MRI data file. BrainWave currently supports DICOM, 3D NIfTI and CTF .mri formats. If selecting a DICOM series that consists of multiple files select one of the image files (e.g., 001.dcm) inside the directory. (*On MacOS you may need to use the Show Options button to select different file formats*).

2. After conversion is completed you will be prompted to enter a subjectID. Brainwave will save the MRI (interpolating and padding as needed) to create a standard NIfTI format (1mm isotropic, 256x256x256 voxels in RAS orientation) and save it in dedicated folder (e.g., enter "003" to save as 003_MRI). All MRI related files will be saved in this folder. 
* **IMPORTANT: The name you choose MUST match the participant ID for all MEG datasets for that participant.**

3. BrainWave will open the newly converted file in the MRI Viewer Module. Confirm that the MRI looks correct.

#### Running Freesurfer

* **IMPORTANT: Even if you have previously run Freesurfer on MRI scans for a participant (e.g., original DICOM series), you must run recon-all on the NIfTI image created in the previous step for correct alignment to the MNI template and MEG coordinate system.**


#### Option 1: Freesurfer preprocessing for MNI coregistration and using individual MRI surfaces (Recommended)

1. Outside of Matlab, open a terminal.

2. Navigate to the directory with the subject MRI file file created by BrainWave (e.g., 003_MRI/003.nii) 

3. Type in the following

> recon-all -s subjectID -i subjectID.nii -sd . -all

*where subjectID is the participant's ID and subjectID will be the Freesurfer output directory. You may choose a different name for the output directory to make it easier to find (e.g., subjectID_fs_all).*

 e.g.,

> recon-all -s 003 -i 003.nii -sd . -all

* Note if the "-sd .' argument is omitted, the Freesurfer output will be saved to the default location (Freesurfer/subjects) instead of saving a local copy in the sid_MRI folder. Both options are OK as long as you remember where you saved the output.

4. After recon-all is completed (can take 3-4 hours) run the freesurfer command to create a high-resolution head surface (this only takes a few minutes)

> mkheadsurf -s 003 -sd . 

or if saved in the Freesurfer default location 

> mkheadsurf -s 003 


#### Option 2: Freesurfer preprocessing for MNI coregistration ONLY (faster)

repeat steps 1 to 3 above with the **-autorecon1** argument instead of the **-all** argument 
> recon-all -s subjectID_coreg -i subjectID.nii -sd . -autorecon1

where subjectID is the participant's ID. e.g.,

> recon-all -s 003_coreg -i 003.nii -sd . -autorecon1

This runs the initial steps of the Freesurfer pipeline to provide co-registration to the MNI template. It only takes 10-15 minutes to complete but no surfaces are created.

---


## Coregistering your MEG and MRI data and Creating Head Models 


### Step 1: Setting Fiducials in MRIViewer


1. Open MRI Viewer from main menu and select the NIfTI MRI file for the participant (e.g., 003_MRI/003.nii)

2. Enable "Edit" mode in the fiducials panel. Use the mouse to navigate to the anatomical location of the fiducial (e.g., Nasion) in the orthogonal slices and select "Set Nasion". Repeat for other fiducials. 

3. Once you have adjusted the fiducials select "Save Fiducials" to save your changes (saved in 003_MRI/003.mat)

4. Import the Freesurfer Coregistration. Select Coregistration->Import MNI Coregistration->Freesurfer. Select the Freesurfer output directory (e.g., 003_MRI/003)

Check the Command Window output that the following files are saved in the MRI folder.  
>'transforms.mat' -------- contains linear transformations from MEG to RAS and RAS to MNI coordinate systems.  
'brainmask.nii' --------- coregistered brain mask generated by Freesurfer  
'003_brainHull.shape' --- a CTF format shape file (in voxel coordinates) of brain surface created from brainmask.nii  
'003_head_surface' ------ a high resolution head surface mesh created by mkheadsurf  

* BrainWave will attempt to use a local installed version of Freesurfer to convert the brainmask.mgz file in the above step. 
* If the above steps fail (e.g., BrainWave cannot find or run Freesurfer from a server or other computer) you will need to complete the additional steps:  
1. Navigate to the Freesurfer output directory (e.g., 003_MRI/003).
2. cd into the subdirectory "mri".  
3. Run the following command:  
mriconvert brainmask.mgz brainmask.nii  
4. Copy the brainmask.nii file to your local MRI directory (003_MRI)  
5. Return to BrainWave and repeat Import MNI coregistration.  


#### *If manual placement of fiducials is deemed sufficient at this point proceed to Step 3 (Create Head Models)*

---


### Step 2: Adjustment of fiducials using 3D MRI View

* Load or Create an MRI scalp surface. 

>**If you have a Freesurfer head surface**  

1. Select Coregistration->View 3D Surface to open the MRI Surface window.

2. Select File->Load Head Surface and select the 003_MRI/003_head_surface file.

>**If you don't have a Freesurfer head surface**  
1. Select Coregistration->Extract Surface. Select default parameters and click OK.  This will create a surface red dots overlaid on the MRI. If the surface appears inaccurate (points inside or outside the head) try increasing or decreasing thresholds value and repeat.  

2. Select Coregistration->View 3D Surface. Will open with the threshold defined head surface.

* Define Fiducial locations on the scalp surface 

1. Select the rotate tool from the menu bar to rotate the image. Select the data cursor tool and use Set Nasion/Set LPA/Set RPA buttons to manually adjust fiducial locations.  

*Optional: alignment using a digitized head surface of the participant (e.g., Polhemus data)*
>Select File, Load headshape and import a CTF / BrainStorm (.pos) digitization file (or other format if provided).
Select “Fit overlay to surface” -- will run Iterative Closest Point fit of points to MRI surface.   
Check fit error. If fit is good (2-3 mm error) select “Set to overlay” in the fiducials section  
If fit error seems too high or fidicial locations don't appear correct you may need to manually adjust starting locations of ficucials and re-fit.  
**NOTE: Fiducial alignment with Polhemus data may have varied success depending on quality of digitization and should be used with caution.**

2. Click **Apply Changes** to update the fiducial settings in the MRI Viewer main window. 

3. Close MRI Surface Window. 

4. To save the new fiducial locations click on **Save Fiducials**. You be prompted to allow the transformation files to be updated as the MEG to RAS coordinate transformation will have changed. 


---


### Step 3: Creating Head Models

Once you have completed defining coregistration you can create single sphere (or multisphere) models for source modeling to each participant's brain surface. This is done by creating a convex hull around the brain mask created in Freesurfer and saving the sphere parameters in MEG coordinates in a CTF format head model file (e.g., single_sphere.hdm).
* **TIP: If you create head models for all raw datasets prior to epoching your data, the epoched datasets will save copies of the head model (*.hdm) files.**

1. Open MRI Viewer from main menu and select the NIfTI MRI file for the participant (e.g., 003_MRI/003.nii)

2. Select menu Head Models->Open Shape File->Select CTF Shape File

3. Find the shape file created for this participant (e.g., 003_brainHull.shape). This will display green dots on the MRI which are the vertices of the brain surface hull. These dots should be aligned to the surface of the brain. 

4. Select menu Head Models->Create Single Sphere Head Model. 

5. A dialog will appear with prompt 'Single-sphere fit complete: ...  ... Write model to datasets?. If you select Yes a dialog will open that will allow you to click on multiple datasets (.ds). Select all raw datasets for this participant to save .hdm files for all datasets. 

6. (Optional) To create multisphere (*local spheres*) head models repeat Steps 4 and 5 with the Create MultiSphere Head Model option. You will be prompted to enter a patch size for the modeling (default parameters recommended).

* **IMPORTANT: If you change the fiducial locations AFTER creating head models the MRI voxel relationship has changed you need to recalculate head models as they are saved in head coordinates not voxel coordinates.**  

## Importing Individual Freesurfer Surfaces (Optional)

If you have run recon-all with the -all option you can import the participant's segmented MRI surfaces for 3D viewing and overlay of source images. 

To do this select **Import Surfaces** in the main menu.  
A dialog will appear. Enter the following information (use Browse buttons to select files).
* Select the participant's Freesurfer output directory (e.g., 003_MRI/003).  
* Select the participant's MRI directory (e.g., 003_MRI).  
* Enter a path and name for the output MAT file. A default name will be automatically created. 
* (Optional) Enter a downsampling factor if desired. It is recommended to use the default (1 = no downsampling).  
This will create a MAT file (default name subjectID_MRI/FS_SURFACES.mat) containing all MRI surfaces in 3 different coordinate system (MEG coordinates, MRI (RAS) coordinates, and MNI coordinates).  After completion it will be opened in the Surface Viewer. Image overlay on these surfaces can be done directly in the 4D Image Viewer.

# Previewing / Preprocessing your MEG Data

To preview and/or edit your MEG data select **Data Editor** from the Main Menu

From File->Open Dataset select a CTF formatted MEG dataset (datasetName.ds). Both single trial and epoched datasets can be viewed. For faster display all data is loaded into memory. Viewing very large datasets may require sufficient memory (16 GB or greater).

#### Importing MEG data in other formats.  
Although BrainWave works with the CTF dataset format you can import MEG data from other MEG manufacturers. The data will be converted to a CTF .ds format and saved.  
To import MEG data use File->Import MEG Data->"data_format"  
>The following MEG formats are supported:  
Elekta-Neuromag / MEGIN (.fif files)  
KIT/Yokogawa (.con data files)  
FieldLine (.fif files) -- still in beta testing  

* **BrainWave has been tested extensively with native CTF data. Importing data from other manufacturers may involve specific preprocessing steps (e.g., co-registration or denoising) prior to importing.**

#### Previewing / Preprocessing the data:

Data Editor will open displaying the first MEG channel. The **Channel Sets** menu can be used to view specific channel types or create custom combinations of channels. Use the Amplitude Scale popup menu to change amplitudes for different channel types. 
 
Use the mouse and arrow keys to move latency cursor and Window Duration controls and scroll bar to scan through the datasets.

#### Viewing options include:

* Applying notch and bandpass filtering, rectification, computing signal envelope etc. using the *Data Parameters* panel.
* Displaying topoplot at the cursor latency (enable *show Map*)
* View single or multiple Marker events using the *Show Marker* dropdown menu.
* Select one or more channels (use shift-click or option-click on Channel Name) to set Channels Good/Bad, plot FFT plotting or exporting of the currently displayed data. 
* Measure latency differences (position cursor then select *Delta Cursor*. Deselect to move latency cursor.) 
* View the average for multi-trial data by selecting *Plot Average*  
* Rename, delete or combine existing CTF Markers using the **Edit Events** menu.  
* Create new events or event latencies from a text file and save as CTF Markers for epoching (see **Event Marking with Data Editor**)  
* You can save and load viewing layouts (Channel Set, # of columns, etc.) using the **File-Save Layout** and **File->Open Layout**. When exiting you will be prompted to save the current layout for each dataset. 

### Saving Modified MEG Datasets

If you want to save a copy of the data with preprocessing applied select **File->Save Dataset As**  
You can save a copy of the data with the following modifications:
* Filtering (when saving you will be asked if you want to apply any currently selected filter settings to the saved data).   
* Deleting Bad Channels/Trials (when saving you will be asked if you want to exclude channels or trials that you have set to Bad in the Viewer).   
* Truncation (you can enter different start and end times for your saved data *NOTE: existing Markers will be adjusted to have corrected latencies!)*  
* Downsampling (appropriate low-pass filtering is required to avoid aliasing).  
* Changing gradient order (for CTF data different synthetic gradient orders can be applied to the saved data.)  

### Event Marking with Data Editor

In cases where you want to manually mark time events and save them for epoching you may create "Events" in Data Editor and then save them as Markers in the MarkerFile.mrk file (recommended) or as a plain text file. Once created you can navigate through existing markers using the arrow buttons. and the Insert, Delete and Delete All buttons on the top right of the window. 

There are 3 methods to create new events (these can be used together or separately).

1. *Manual placement:* Use mouse or arrow keys to place latency cursor at time point of interest and use Insert button to insert events.  

2. *Importing latencies:* Use **File->Edit Events->Import From Text File**.  File should be a plain ASCII text file with one column (one latency per line). 

3. *Threshold Marking*. Use ChannelSets Menu to select a single data channel for threshold marking (e.g., ADC or Trigger channel). If you are using an analog signal (e.g., EMG) you may need to filter and/or apply rectification or envelope first.

>For Threshold Marking select the "Enable" check box in the Threshold Marker panel. The viewed data channel will be plotted in normalized amplitude with thresholding parameters shown as horizontal lines. 
>Adjust Threshold, Amplitude Range, Min Separation and Min. Duration fields and click on **Scan** to create events. The detected events will be shown as vertical lines in the Viewer. You can scan through events using the Event arrow buttons on top right and delete or manually correct any incorrect events. Adjust parameters and repeat Scan until events you want are created.  
> * Use amplitude range to limit detection of threshold events within a specified amplitude range. 
> * Use the Min. Separation field to set a minimum time between events (i.e., ignore suprathreshold events within this time period since the previous event).
> * Use the Min. Duration field to set a minimum time the signal has to remain above the threshold. 

### Creating Conditional Markers

If you have multiple existing Markers for different events you can create a new Marker conditional on other Markers. (e.g., to create a new Marker that ONLY occurs withing a time window of another Marker event).

Select **Edit Events->Create Conditional Event**.  

1. Select a Sync Marker. This is the Marker that the event will be time locked to (t = 0.0 s).

2. Using the popup menus select a Marker for Inclusion Mask. For example, if you want to select a Marker called "buttonPress" that occured within one second after an event called "goStim". set the Sync Event to "buttonPress", the Inclusion Mask Marker to "goStim" and set the Inclusion Mask Window from 0 to 1 s.

4. Pres *Update Events* and you will see the number of included events. If this looks correct Click on *Create Event*.

5. Close Dialog. You should now see the events corresponding to the conditional event markers. These events can be edited and/or saved using the Event Editing Tools.

*To EXCLUDE Marker events relative to another Marker repeat Steps 1 to 5 with an Exclusion Mask and time window.  Inclusion and Exclusion masks can be combined. 


# Epoching Your Datasets

For beamformer or dipole analysis you will need to create an epoched dataset of multiple trials per condition time locked to latencies (saved as Markers or in a text file) from the raw data. The time window chosen can be adjusted when setting beamformer time windows and displaying output (e.g., virtual sensors) so select an epoch window that is sufficient to include different pre-stimulus baselines, active and baseline windows etc. During epoching you may apply additional processes such as excluding trials with artifacts, pre-filter the data, downsample etc.

1. Under File Menu->Load CTF Datasets. Select a single trial MEG dataset. The dataset acquisition parameters will be listed along with the Fiducial locations in device coordinates.

2. In Epoch Selection panel click on **Multiple Epochs** and click **Load from Marker File** to select a Marker Event you want to time lock to in the list (or alternatively  **Load from Text File**) to load latencies from a plain ASCII text file. The latencies will be listed in the text box.

3. Set your desired epoch window (use negative numbers to indicate time preceding the Marker event). *Min Separation* can be set to exclude events too close together. *Latency Correction* can be used to subtract a fixed amount of time relative to the Marker Event. 

4. Preview the raw data trials for some or all channels in the Preview window by scrolling through the latencies to check for bad trials. 

5. Set any Pre-processing parameters, such as bandpass or line frequency pre-filtering and downsampling. For CTF data if continuous head localization (CHL) was enabled during collection the *Use Mean Head position* option will be selected by default. This is highly recommended as it will set the head position (relative to the MEG sensors) to the mean of the head position during each epoch. This will average out any head movement over the recording and will be much more accurate than the default head position measured at the beginning of the recording. In BrainWave minimal preprocessing is usually recommended. This is because (unlike dipole fitting or minimum-norm analysis) beamforming algorithms are designed to 'unmix' both brain and enviromental sources efficiently. In this case removing artifacts using ICA or similar decomposition methods are often unecessary and can both alter the data and reduce the rank of the data covariance matrix requiring significant regularization reducing spatial resolution. We recommend instead excluding trials containing very large artifacts or SQUID resets if necessary which can be done in the next step.

6. (Optional) Use the Epoch Rejection panel parameters to automatically exclude bad trials that exceed certain amplitudes (large environmental events or SQUID resets) or have excessive head motion in that trial. We recommend previewing the amount of overall head motion using the **Plot Head Motion** option. Automatic rejection of trials with large head motion can be done by enabling the *Mean Sensor Motion exceeds...*. BrainWave will exclude trials by computing the mean motion of all sensors (or the selected subset) relative to the head. This method accounts for both translational and rotational motion of the head relative to the sensors. 

7. Select output file name. Ensure the **Save As** field is set to an appropriate name and path for the epoched data. You may use the Label field to append additional text. 

8. Select **Create Datasets**.  The epoched data will be opened in the **DataPlot/Dipole Fitting** module for viewing. 

**Batch Option**

* NOTE: multiple datasets can be selected in the Open File dialog. In this case identical processsing will be applied to all the datasets selected. *NOTE: this assumes that datasets will have IDENTICAL Markers with same spelling in the Marker File!* 

Alternatively, for epoching many datasets at once (even with different parameters) you can use the batching option under the Batch menu.
1. Batch->Open New Batch
2. Repeat Steps 1 to 7, then click on Add to Batch when done. Repeat for each dataset. 
3. Select  **Batch->Close Batch** then **Run Batch** to beging epoching.

## You are now ready to start source analysis with BrainWave!  


















