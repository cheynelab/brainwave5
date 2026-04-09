%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_MRIViewer(mriFile, [overlayFile])
%
%   Module for viewing MRI files, setting fiducials, shape extraction and
%   creating single and multisphere head models
%
%   written by Zhengkai Chen and Douglas Cheyne, 2012
%
%
%   Version 2.0 -   Nov, 2018 
%            - major updates for version 3.6
%
%   Version 4.0 - April 2022
%           - major changes to drawing routines, removed mesh import to
%             SurfaceViewer module. Lots of new options...
%             D. Cheyne
%
%   Version 4.2 - Feb 2023
%           - revisions for github. Now calls bw_readMeshFile
%
%   Version 5.0 -  March, 2025
%           - replacing SPM normalization with affine (Freesurfer)
%
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
% (c) D. Cheyne, 2012. All rights reserved. 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function bw_MRIViewer(mriFile, overlayFile)

global BW_PATH;

%declaring necessary variables
img = [];
img_RAS =[];
mmPerVoxel = 0;
file_name='';
file_path='';
mriName = '';
File ='';

isTemplate = 0;        
orange = [0.8,0.4,0.1];
sag_hor=[];
sag_ver=[];
cor_hor=[];
cor_ver=[];
axi_hor=[];
axi_ver=[];
sag_hor_big=[];
sag_ver_big=[];
cor_hor_big=[];
cor_ver_big=[];
axi_hor_big=[];
axi_ver_big=[];
cursor_color = [1.0,0.7,0.3];
sagaxis=[];
coraxis=[];
axiaxis=[];
max_dim = 256;
slice_dim = [max_dim max_dim max_dim];
slice1_RAS = round(max_dim/2)-1;
slice2_RAS = round(max_dim/2)-1;
slice3_RAS = round(max_dim/2)-1;
oldcoords=[slice1_RAS slice2_RAS slice3_RAS];
slice1_big_RAS = slice1_RAS;
slice2_big_RAS = slice2_RAS;
slice3_big_RAS = slice3_RAS;

image_size = [max_dim max_dim max_dim];
img_display = zeros(max_dim,max_dim,max_dim);
img_display1 = zeros(max_dim,max_dim,max_dim);
mri_nii = [];
na_RAS = [0 0 0];
le_RAS = [0 0 0];
re_RAS = [0 0 0];

shape_vox_x=[];
shape_vox_y=[];
shape_vox_z=[];

shape_points=[];
shape_points_RAS = [];
shape_points_RPI = [];
showAllPoints = 0;

surface_points=[];
surface_faces = [];  

sensor_points = [];
sensor_points_RPI = [];

dip_params = [];
dip_params_RPI = [];
dip_orient_RPI = [];
s = {'red','green','yellow','white','cyan','magenta','blue'};   
dipColors = repmat(s,1,50); % repeat colors for up 350 dipoles
showAllDipoles = 0;

meshdata = [];
ph = [];

coord_x=[];
coord_y=[];
coord_z=[];
Transform_M=[];
surface_points_RPI = [];
surface_points_orien_RPI=[];

sphere_o = [];
sphere_r = [];
origin_vox = [];
radius_vox = [];
sphereList = [];
sphereChanList = [];
isSingleSphere = 0;

maxBrightness = 4.0;     % allow low contrast images to saturate
contrast_value = 0.5 * maxBrightness;

% default point dimensions
pt_size = 1.5;
tail_len = 2;
tail_width = 1;
tail_show = 0;
fid_size = 3;

% shape_file = [];
edit_fids = 0; 
template_val = 0;
Continue = 1;
template_filename='';

mni_coord = [-33 -20 58];
meg_coord = [0.2 3.0 8.5];

% multiple time point overlay
FILE_LIST = [];
global_max = 1;
defaultThreshold = 0.3;

img_RAS_original = [];
deface_bb = [50 120 -80 80 -120 0];
enable_defacing = 0;

surfaceThreshold = 15; 
surfaceResolution = 2; 


SPM_BB = [-78 -112 -50 78 76 86];
transforms = [];


%adding nifti functions folder to path
template_path=strcat(BW_PATH,filesep,'template_MRI/');
if exist(template_path,'dir') ~= 7   % should not happen as folder is part of BW
    fprintf('error: template MRI folder is missing...\n');
else
    addpath(template_path);
end

% open dialog window
scrsz = get(0,'ScreenSize');

f=figure('Name', 'MRI Viewer', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 850 850],...
    'menubar','none','numbertitle','off', 'Color','white',...
    'WindowButtonUpFcn',@stopdrag,'WindowButtonDownFcn',@buttondown);

if ispc
    movegui(f,'center');
end
subplot(2,2,1); imagesc(zeros(max_dim, max_dim)); axis off;
subplot(2,2,2); imagesc(zeros(max_dim, max_dim)); axis off;
subplot(2,2,3); imagesc(zeros(max_dim, max_dim)); axis off;

% hmap = colormap(hot(128));
hmap = colormap(jet(128));

gmap = colormap(gray(128));
cmap = [gmap; hmap];


% make a custom colorbar (compressed)  
bot = 0.59;
height = 0.33 / size(hmap,1)*2;  
for k=1:size(hmap,1)/2
    idx = k*2;
    c_bar(k) = annotation('rectangle',[0.94 bot 0.025 height],'FaceColor',hmap(idx,1:3),'visible','off');
    bot = bot+height;
end

ph = [];    
ph = patch('Vertices',[], 'Faces', [] );
ph.Clipping = 'off';    
cl=camlight('left');
set(cl,'Color',[0.6 0.6 0.6]);
cr=camlight('right');
set(cr,'Color',[0.6 0.6 0.6]);

% pos/neg color scale
 
overlay.image = [];
maskOverlay.image = [];
Dip_File = {};
currentDip = 1;

FILE_MENU=uimenu('Label','File');
uimenu(FILE_MENU,'label','Open MRI file...','Accelerator','O','Callback',@open_MRI_Callback);
uimenu(FILE_MENU,'label','Open template MRI...','Callback',@open_templateMRICallback);
SAVE_FILE = uimenu(FILE_MENU,'label','Save MRI as...','Callback',@save_MRICallback, 'enable','off','separator','on');
EXPORT_MRI = uimenu(FILE_MENU,'label','Export to CTF Format...','Callback',@export_MRICallback, 'enable','off');
uimenu(FILE_MENU,'label','Close','Callback',@my_closereq,'Accelerator','W','separator','on');
HDM_MENU=uimenu('Label','Head Models');
OPEN_SHAPE = uimenu(HDM_MENU,'label','Open Shape File...','enable','off');
uimenu(OPEN_SHAPE,'label','CTF Shape file (*.shape)','enable','on','callback',@open_CTFShapeCallback);
uimenu(OPEN_SHAPE,'label','CTF (Brainstorm) Polhemus file (*.pos)','enable','on','callback',@open_PolhemusCallback);
uimenu(OPEN_SHAPE,'label','Brainstorm Channel file (*.mat)','enable','on','callback',@open_ChannelCallback);
uimenu(OPEN_SHAPE,'label','Surface point file (*.sfp)','enable','on','callback',@open_SFPCallback);
FIT_SINGLE_SPHERE = uimenu(HDM_MENU,'label','Create Single Sphere Head Model','enable','off','callback',@fit_sphere_callback);
FIT_MULTI_SPHERE = uimenu(HDM_MENU,'label','Create Multisphere Head Model','enable','off','callback',@multiplefit_sphere_callback);
WARP_TEMPLATE = uimenu(HDM_MENU,'label','Warp template to head shape','separator','on','enable','off','callback',@warp_templateCallback);
CLR_SHAPE = uimenu(HDM_MENU,'label','Clear Shape','enable','off','separator','on','callback',@clear_shapeCallback);

NORM_MENU = uimenu('Label','Coregistration');
IMPORT_MNI = uimenu(NORM_MENU,'label','Import MNI coregistration...','enable','off');
VIEW_SURFACE = uimenu(NORM_MENU,'label','View 3D Surface','enable','off','callback',@view_surfaceCallback);
EXTRACT_MRI_SURFACE = uimenu(NORM_MENU,'label','Extract MRI surface...','enable','off','callback',@extract_surfaceCallback);
uimenu(IMPORT_MNI,'label','Freesurfer...','enable','on','callback',@import_freesurfer_Callback);
% uimenu(IMPORT_MNI,'label','CIVET...','enable','on','callback',@import_civet_Callback);
GOTO_MNI = uimenu(NORM_MENU,'label','Goto MNI coordinate ...','separator','on','enable','off','callback',@gotoMNI_callback);
GOTO_MEG = uimenu(NORM_MENU,'label','Goto MEG coordinate ...','enable','off','callback',@gotoMEG_callback);
CLR_SURFACE = uimenu(NORM_MENU,'label','Clear Surface','enable','off','separator','on','callback',@clear_surfaceCallback);

OVERLAY_MENU = uimenu('label','Overlays');
OPEN_OVERLAY = uimenu(OVERLAY_MENU,'label','SAM/ERB images (*.svl)...','enable','off','callback',@open_overlay_callback);
OPEN_MNI_OVERLAY = uimenu(OVERLAY_MENU,'label','Normalized SAM/ERB images (*.nii)...','enable','off','callback',@open_mni_overlay_callback);
MASK_OVERLAY = uimenu(OVERLAY_MENU,'label','Mask Overlay ...','enable','off','callback',@open_mask_overlay_callback);
OPEN_SENSORS = uimenu(OVERLAY_MENU,'label','MEG Sensor Overlay...','enable','off','callback',@open_sensorsCallback);
OPEN_DIP = uimenu(OVERLAY_MENU,'label','Dipole Overlay...','enable','off','callback',@open_dipCallback);
OPEN_MESH=uimenu(OVERLAY_MENU,'Label','Cortical Surface','enable','off');
uimenu(OPEN_MESH,'label','Load FreeSurfer Surface ...','callback',@loadFSMeshCallback);
uimenu(OPEN_MESH,'label','Load CIVET Surface ...','callback',@loadCIVETMeshCallback);
CLEAR_OVERLAY = uimenu(OVERLAY_MENU,'label','Clear Overlays','enable','off','separator','on','callback',@clear_overlayCallback);


OPT_MENU=uimenu('Label','Options');
uimenu(OPT_MENU,'label','Display Options...','callback',@display_optCallback);
DEFACE_MENU = uimenu(OPT_MENU,'label','Defacing ...','enable','off','callback',@deface_optCallback);

% initial menus off until MRI is loaded

WORKSPACE_TEXT_TITLE = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.15 0.957 0.8 0.03],'String','MRI File:','HorizontalAlignment','left',...
    'BackgroundColor','White', 'enable','off');

WORKSPACE_TEXT_TITLE2 = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.15 0.942 0.8 0.028],'String','Surface File:','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','Red', 'enable','off');

WORKSPACE_TEXT_TITLE3 = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.15 0.925 0.8 0.028],'String','Shape File:','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor',[0 0.5 0.1], 'enable','off');

CURSOR_TEXT = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
        [0.13 0.48 0.4 0.03],'String','','HorizontalAlignment','left',...
        'BackgroundColor','White', 'enable','on');
CURSOR_TEXT2 = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
        [0.13 0.46 0.7 0.03],'String','','HorizontalAlignment','left',...
        'BackgroundColor','White', 'enable','on');

    function my_closereq(~,~)
        delete(gcf);
    end
    

    function open_MRI_Callback(~,~)
        
        [fileName, filePath, ~] = uigetfile('*.nii','NIfTI file(*.nii)',...
            'Select a NIfTI MRI file');
        
        if isequal(fileName,0) || isequal(filePath,0)
            return;
        end
                
        File = fullfile(filePath, fileName);
        
        template_val = 0;
        
        openMRI(File);
        
        isTemplate = 0;  
        
    end

    function open_templateMRICallback(~,~)
        
                        
        % template path already defined??       
        bwpath=which('bw_MRIViewer');
        template_path=strcat(bwpath(1:end-14),'template_MRI/');
        if exist(template_path,'dir') ~= 7   % should not happen as folder is part of BW
            fprintf('error: template_MRI folder is missing...\n');
            return
        end
               
        template_val = 1;
        scrsz=get(0,'ScreenSize');
        f2=figure('Name', 'Select template', 'Position', [(scrsz(3)-500)/2 (scrsz(4)-400)/2 500 400],...
            'menubar','none','numbertitle','off');
        
        h1 = uibuttongroup('units','normalized','position',[0.1 0.2 0.8 0.7],'SelectionChangeFcn', @radio_callback);
        a1 = uicontrol('style','radiobutton','parent',h1,'units','normalized',...
            'position',[0.1 0.8 0.8 0.1],'string','Default adult template (ch2.nii) ',...
            'Tag','1','fontsize',10,'FontWeight','normal', 'Handlevisibility','off');      
        c1 = uicontrol('style','radiobutton','parent',h1,'units','normalized','position',[0.1 0.65 0.8 0.1],...
            'string','Other:','Tag','2','fontsize',10,'FontWeight','normal', 'Handlevisibility','off');
 
        % get templates
        templates_filename={};        
        filenames = dir([template_path '*.nii']);
        numCustom = 0;
        for i = 1:length(filenames)            
            if strcmp(filenames(i).name,'ch2.nii')      
                numCustom = numCustom + 1;
                templates_filename{numCustom}=filenames(i).name;
            end
        end        
        
        if numCustom == 0
            set(c1,'enable','off');
        end
        temp_filename = '';
        
        TEMPLATE_LISTBOX=uicontrol('Style','Listbox','parent',h1,'enable','on','FontSize',11,'Units','Normalized','Position',...
            [0.15 0.1 0.8 0.45],'String',templates_filename,'HorizontalAlignment','Center','BackgroundColor',...
            'White','min',1,'max',1,'Callback',@TEMPLATE_LISTBOX_CALLBACK);

        function radio_callback(~,~)
            val = get(get(h1,'SelectedObject'),'Tag');
            if (val == '2')
                set(TEMPLATE_LISTBOX,'enable','on');
            else
                set(TEMPLATE_LISTBOX,'enable','off');
            end
        end    
                
        function TEMPLATE_LISTBOX_CALLBACK(src,~)
            temp_name = get(src,'string');
            select=get(src,'value');
            temp_filename = strcat(template_path,temp_name(select));         
        end        
        
        uicontrol('Units','Normalized','Position',[0.25 0.05 0.25 0.06],'String','Load Template',...
            'FontSize',10,'FontWeight','b','ForegroundColor',...
            'black','Callback',@save_templatecallback);

        function save_templatecallback(~,~)
            template_val = str2double(get(get(h1,'SelectedObject'),'Tag'));
            if template_val == 2 && isempty(temp_filename)
                warndlg('Select a template');
                return;
            end
            uiresume(gcf);
            Continue = 1;            
        end
        
        uicontrol('Units','Normalized','Position',[0.6 0.05 0.12 0.06],'String','Cancel',...
            'FontSize',10,'FontWeight','b','ForegroundColor',...
            'black','Callback',@cancel_templatecallback);
        function cancel_templatecallback(~,~)            
            uiresume(gcf);
            Continue = 0;            
        end  
        
        uiwait(gcf);
        close(f2);
        
        if (Continue ==0)
            return;
        end
        
        switch template_val
            case 1
                template_filename = strcat(template_path,'ch2.nii');
                
            case 2
                template_filename = char(temp_filename);           
                
            otherwise
                return;                
        end

        openMRI(template_filename);
        
        if isempty(mri_nii)
            return;
        end
        
        isTemplate = 1;         % set flag so we know we are viewing template
 
        set(OPEN_SHAPE, 'enable', 'off');
        set(OPEN_OVERLAY, 'enable', 'off');
        set(OPEN_MNI_OVERLAY, 'enable', 'off');
        set(MASK_OVERLAY, 'enable', 'off');
        set(OPEN_DIP, 'enable', 'off');
        set(OPEN_MESH, 'enable', 'off');
        set(FIT_SINGLE_SPHERE, 'enable', 'off');
        set(FIT_MULTI_SPHERE, 'enable', 'off');
        set(CLR_SHAPE, 'enable', 'off');
        set(WARP_TEMPLATE, 'enable', 'off');
        set(SAVE_FILE, 'enable', 'on');
        set(EXPORT_MRI, 'enable', 'on');
        set(EXTRACT_MRI_SURFACE, 'enable', 'off');
        set(GOTO_MNI, 'enable', 'off');
        set(GOTO_MEG, 'enable', 'off');
        set(OPEN_SENSORS,'enable','off');
        set(OVERLAY_MENU,'enable','off');
        set(IMPORT_MNI,'enable','off');
       
        matFileName = strrep(template_filename, '.nii', '.mat');
        if exist(matFileName,'file')            
            s = sprintf('Use pre-defined fiducials for this template?');
            response = bw_warning_dialog(s);
            if (response == 0)
                na_RAS = [0 0 0];
                le_RAS = [0 0 0];
                re_RAS = [0 0 0];               
                updateFidText;
                warndlg('Use Edit mode to set Fiducials for this template.');
            else
                set(OPEN_SHAPE, 'enable', 'on');
                set(OPEN_OVERLAY, 'enable', 'on');
                set(OPEN_MNI_OVERLAY, 'enable', 'on');
                set(MASK_OVERLAY, 'enable', 'on');
                set(OPEN_DIP, 'enable', 'on');
                set(OPEN_MESH, 'enable', 'on');
                set(SAVE_FILE, 'enable', 'on');
                set(EXPORT_MRI, 'enable', 'on');
                set(EXTRACT_MRI_SURFACE, 'enable', 'on');
                set(GOTO_MNI, 'enable', 'on');
                set(GOTO_MEG, 'enable', 'on');
                set(OPEN_SENSORS,'enable','on');
                set(OVERLAY_MENU,'enable','on');
                set(IMPORT_MNI,'enable','on');
          end
        else
           warndlg('There are no pre-defined fiducials for this template. Setting to defaults.');
        end
                    
    end

    function save_MRICallback(~,~)

        [filename, pathname, ~] = uiputfile( ...
            {'*','MRI_DIRECTORY'}, ...
            'Enter Subject ID for MRI Directory');

        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        subjectID = fullfile(pathname, filename);
        save_MRI_dir(subjectID);            
        
    end

    function export_MRICallback(~,~)
        
        [filename, pathname, ~] = uiputfile( ...
            {'*.mri','CTF MRI file (*.mri)'}, ...
            'Enter Name for MRI file ');

        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        filename_full = fullfile(pathname, filename);

        [xdim, ydim, zdim] = size(img);
        if (xdim ~= 256 && ydim ~= 256 && zdim ~= 256)
            fprintf('img is not correct size or does not exist\n');
            return;
        end

        fprintf('Saving MRI data in CTF format...\n');

        % **** Version 4.0 
        % replaced mex function with eeglab matlab version 

        % transposing for ctf_write_mri is different 
        % don't swap axes but need to flip image in 
        % anterior-posterior (y axis ) and inf-sup (z axis)
        % dir
        img_RPI = img_RAS;

        % then flip anterior-posterior and inferior-superior directions..
        img2 = flipdim(img_RPI,2);
        img_RPI = flipdim(img2,3);
        clear img2;


        mri.img = round(img_RPI);

        na_RPI = [na_RAS(1)+1 slice_dim(2)-na_RAS(2) slice_dim(3)-na_RAS(3)];
        le_RPI = [le_RAS(1)+1 slice_dim(2)-le_RAS(2) slice_dim(3)-le_RAS(3)];
        re_RPI = [re_RAS(1)+1 slice_dim(2)-re_RAS(2) slice_dim(3)-re_RAS(3)];

        % need to pass mri.hdr structure that populates all fields of the CTF MRI header.            
        mri.hdr.identifierString = 'CTF_MRI_FORMAT VER 2.2';  
        mri.hdr.imageSize = 256;
        mri.hdr.dataSize = 2;
        mri.hdr.clippingRange = 255;
        mri.hdr.imageOrientation = 0;
        mri.hdr.mmPerPixel_sagittal = mmPerVoxel;
        mri.hdr.mmPerPixel_coronal = mmPerVoxel;
        mri.hdr.mmPerPixel_axial = mmPerVoxel;
        mri.hdr.headOrigin_sagittal = 0;
        mri.hdr.headOrigin_coronal = 0;
        mri.hdr.headOrigin_axial = 0;
        mri.hdr.rotate_coronal = 0;
        mri.hdr.rotate_sagittal = 0;
        mri.hdr.rotate_axial = 0;
        mri.hdr.orthogonalFlag = 0;
        mri.hdr.interpolatedFlag = 0;
        mri.hdr.originalSliceThickness = mmPerVoxel;

        % save CTFtoVoxel transform matrix in header using RPI fiducials (for Wei ! ) 
        tmat = bw_getAffineVox2CTF(na_RPI, le_RPI, re_RPI, mmPerVoxel);            
        mri.hdr.transformMatrix = inv(tmat);

        mri.hdr.HeadModel_Info.Nasion_Sag = na_RPI(1);
        mri.hdr.HeadModel_Info.Nasion_Cor = na_RPI(2);
        mri.hdr.HeadModel_Info.Nasion_Axi = na_RPI(3);
        mri.hdr.HeadModel_Info.LeftEar_Sag = le_RPI(1);
        mri.hdr.HeadModel_Info.LeftEar_Cor = le_RPI(2);
        mri.hdr.HeadModel_Info.LeftEar_Axi = le_RPI(3);
        mri.hdr.HeadModel_Info.RightEar_Sag = re_RPI(1);
        mri.hdr.HeadModel_Info.RightEar_Cor = re_RPI(2);
        mri.hdr.HeadModel_Info.RightEar_Axi = re_RPI(3);

        mri.hdr.HeadModel_Info.defaultSphereX = 0.0;
        mri.hdr.HeadModel_Info.defaultSphereY = 0.0;
        mri.hdr.HeadModel_Info.defaultSphereZ = 5.0;
        mri.hdr.HeadModel_Info.defaultSphereRadius= 8.0;

        mri.hdr.Image_Info.modality = 0;

        mri.hdr.Image_Info.manufacturerName = 'unknown';
        mri.hdr.Image_Info.instituteName = 'unknown';
        mri.hdr.Image_Info.patientID = 'unknown';
        mri.hdr.Image_Info.dateAndTime = 'unknown';
        mri.hdr.Image_Info.scanType = 'unknown';
        mri.hdr.Image_Info.contrastAgent = 'unknown';
        mri.hdr.Image_Info.imagedNucleus = 'unknown';
        mri.hdr.Image_Info.Frequency = 0.0;
        mri.hdr.Image_Info.FlipAngle = 0.0;
        mri.hdr.Image_Info.FieldStrength = 0.0;
        mri.hdr.Image_Info.EchoTime = 0.0;
        mri.hdr.Image_Info.RepetitionTime = 0.0;
        mri.hdr.Image_Info.InversionTime = 0.0;
        mri.hdr.Image_Info.NoExcitations = 1;
        mri.hdr.Image_Info.NoAcquisitions = 1;

        mri.hdr.Image_Info.commentString = 'save from Brainwave using EEGLAB ctf_write_mri.m';
        mri.hdr.Image_Info.forFutureUse = '';          
        ctf_write_mri(mri, filename_full, 1);
            
    end

    % File I/O    
    % open a previously converted MRI file, should already be isotropic but may not have fiducials set...
    function openMRI(File)
        
        tstr=sprintf('MRI File: %s',File);
        set(WORKSPACE_TEXT_TITLE,'string', tstr, 'enable','on','units','normalized','fontname','lucinda');
                
        clear_shapeCallback;
        clear_surfaceCallback;
        
        img_RAS_original = [];  % bug fix 4.2 if case defacing option used doesn't get reset
        enable_defacing = 0;
        
        meshdata = [];
        sphere_o=[];
        sphere_r=[];
        sphereList=[];
        overlay.data = [];
        transforms = [];

        tstr=sprintf('Shape File: ');
        set(WORKSPACE_TEXT_TITLE3, 'string', tstr, 'enable', 'on', 'units','normalized','fontname','lucinda');
        
        set(FIT_SINGLE_SPHERE,'enable','off');
        set(FIT_MULTI_SPHERE,'enable','off');
        set(CLR_SHAPE, 'enable', 'off');
        set(WARP_TEMPLATE, 'enable', 'off');
        set(CLR_SURFACE, 'enable', 'off');   
        enable_overlay_controls('off');

        set(dipoleMenu, 'visible', 'off');
        set(showDipoleCheck, 'visible', 'off');

        
        [filePath,filename,~] = fileparts(File);
        file_name=filename;
        file_path=filePath;
        mri_nii = load_nii(File);
        fprintf('Reading MRI file %s, Voxel dimensions: %g %g %g\n',...
            File, mri_nii.hdr.dime.pixdim(2), mri_nii.hdr.dime.pixdim(3), mri_nii.hdr.dime.pixdim(4));
 
        if  ((mri_nii.hdr.dime.pixdim(2) ~= mri_nii.hdr.dime.pixdim(3)) ) ...
                && ((mri_nii.hdr.dime.pixdim(2) ~= mri_nii.hdr.dime.pixdim(4)) )
            errordlg('This MRI file is not isotropic. Use Import MRI to import NIfTI files...\n');
            return;
        end
         
        set_sagittal_callback;
        set_coronal_callback;
        set_axis_callback;    
        
        slice_dim = [mri_nii.hdr.dime.dim(2) mri_nii.hdr.dime.dim(3) mri_nii.hdr.dime.dim(4)];
        max_dim = max(slice_dim);
        slice1_RAS = round(max_dim/2)-1;
        slice2_RAS = round(max_dim/2)-1;
        slice3_RAS = round(max_dim/2)-1;
        oldcoords=[slice1_RAS slice2_RAS slice3_RAS];
        
        mmPerVoxel = mri_nii.hdr.dime.pixdim(2);      
        img_RAS=mri_nii.img;

        mriName = File;
              
        % flip z direction RAS -> RAI
        img2 = flipdim(img_RAS,3);
        % flip y direction RAI -> RPI
        img = flipdim(img2,2);
        
        if(mri_nii.hdr.dime.datatype==2)
            img_display1=uint8(img);
        else
            maxVal = max(max(max(img)));
            maxVal = double(maxVal);
            scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
            img_display1 = round(scaleTo8bit * img); 
            img_display1 = uint8(img_display1);
        end
        clear img2;
              
        % load fiducials in .mat file
        fd_mat = strrep(File,'.nii','.mat');
        fid=fopen(fd_mat);
        if (fid>0)
            fd=load(fd_mat);
            na_RAS= fd.na;
            le_RAS= fd.le;
            re_RAS= fd.re;
            mmPerVoxel = fd.mmPerVoxel;
        else
            na_RAS=[0 0 0]; %default values if no fiducial information included
            le_RAS=[0 0 0];
            re_RAS=[0 0 0];
        end        

        % assign transforms if exist.
        transforms = getMNITransforms;

        updateFidText;
        updateDisplay;
                
        tstr=sprintf('MRI File: %s',mriName);
        set(WORKSPACE_TEXT_TITLE,'string', tstr, 'enable','on','units','normalized','fontname','lucinda');
        set(WORKSPACE_TEXT_TITLE2,'string', 'Surface File:', 'enable','on','units','normalized','fontname','lucinda');
        set(WORKSPACE_TEXT_TITLE3,'string', 'Shape File:', 'enable','on','units','normalized','fontname','lucinda');
    
        slice3_str = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT, 'String', slice3_str);
        slice1_str = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT, 'String', slice1_str);
        slice2_str = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT, 'String', slice2_str);
        
        set(AXIS_SLIDER, 'max', slice_dim(3));
        set(CORONAL_SLIDER, 'max', slice_dim(2));
        set(SAGITTAL_SLIDER, 'max', slice_dim(1));
        
        set(AXIS_SLIDER, 'sliderStep', [1 1]/(slice_dim(3)-1));
        set(CORONAL_SLIDER, 'sliderStep', [1 1]/(slice_dim(2)-1));
        set(SAGITTAL_SLIDER, 'sliderStep', [1 1]/(slice_dim(1)-1));
        
        set(AXIS_SLIDER, 'value', slice_dim(3)-slice3_RAS);
        set(CORONAL_SLIDER, 'value', slice_dim(2)-slice2_RAS);
        set(SAGITTAL_SLIDER, 'value', slice1_RAS+1);
        
        set(AXIS_SLIDER, 'SliderStep', [1 1]/(slice_dim(3)-1));
        set(CORONAL_SLIDER, 'SliderStep', [1 1]/(slice_dim(2)-1));
        set(SAGITTAL_SLIDER, 'SliderStep', [1 1]/(slice_dim(1)-1));
    
        if ~isempty(mri_nii)
            set(OPEN_SHAPE, 'enable', 'on');
            set(OPEN_OVERLAY, 'enable', 'on');
            set(OPEN_MNI_OVERLAY, 'enable', 'on');
            set(MASK_OVERLAY, 'enable', 'on');
            set(OPEN_DIP, 'enable', 'on');
            set(OPEN_MESH, 'enable', 'on');
            set(SAVE_FILE, 'enable', 'on');
            set(EXPORT_MRI, 'enable', 'on');
            set(EXTRACT_MRI_SURFACE, 'enable', 'on');
            set(VIEW_SURFACE, 'enable', 'on');
            set(GOTO_MNI, 'enable', 'on');
            set(GOTO_MEG, 'enable', 'on');
            set(OPEN_SENSORS,'enable','on');            
            set(OVERLAY_MENU,'enable','on');
            set(IMPORT_MNI,'enable','on');
            set(NORM_MENU,'enable','on');
            set(DEFACE_MENU,'enable','on');
        end
   
    end
 
    function save_MRI_dir(file)
        
        if isequal(img_RAS,[])
            return;
        end
 
        [path, subject_ID, ~] = fileparts(file);
        filename = fullfile(path, subject_ID);
        file_directory=strcat(path, filesep, subject_ID,'_MRI');

        mriName = strcat(file_directory,filesep, subject_ID, '.nii');        
        if exist(file_directory,'dir')
            fprintf('Using existing directory %s...\n', file_directory);
        else
            mkdir(file_directory);
        end

        tstr1=sprintf('File: %s',mriName);
        set(WORKSPACE_TEXT_TITLE,'string', tstr1, 'enable','on');
        file_name=filename;
        file_path= file_directory;

        if exist(mriName,'file')
            s = sprintf('File %s already exists.  Do you want to overwrite?\n', mriName);
            response = bw_warning_dialog(s);
            if response == 0
                return;
            end
        end
        
        datatype = mri_nii.hdr.dime.datatype;
        descrip = mri_nii.hdr.hist.descrip;
        %  origin = mri_nii.hdr.hist.originator(1:3);
        %dims = size(img_RAS);
        %origin = [round(dims(1)/2) round(dims(2)/2) round(dims(3)/2)];
        nii = make_nii(img_RAS, mmPerVoxel, [], datatype, descrip);
        %nii_spm = make_nii(img_RAS, mmPerVoxel, origin, datatype, descrip);

        fprintf('Saving to isotropic NIfTI file %s\n', mriName);
        save_nii(nii, mriName);
        
  
        % save the .mat file

        % na, le, re are fiducials still in RPI (display) coordinates
        % convert to RAS 
        fprintf('Voxel (RAS) to MEG coordinate transformation matrix: \n');
        fprintf('Voxel origin (0,0,0) is left, posterior, inferior corner of volume\n');
        M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);

        % this renaming is because of need to save fields with correct names
        na = na_RAS;
        le = le_RAS;
        re = re_RAS;
        matFileName = strrep(mriName, '.nii', '.mat');
        if exist(matFileName,'file')
            s = sprintf('There is a .mat file already exist, save changes may change the original fiducial values. Are you sure to save the fiducials?');
            response = bw_warning_dialog(s);
            if (response == 0)
                return;
            else
                fprintf('Saving Voxel to MEG coordinate transformation matrix and fiducials in %s\n', matFileName);
                save(matFileName, 'M', 'na','le','re','mmPerVoxel');
            end
        else
            fprintf('Saving Voxel to MEG coordinate transformation matrix and fiducials in %s\n', matFileName);
            save(matFileName, 'M', 'na','le','re','mmPerVoxel');
        end    
 
    end

    % save fiducials
    function save_change_fiducials_callback(~,~)        

        M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);
        
        % this odd code is because struct in .mat file has to have na, le, re labels...
        na = na_RAS;
        le = le_RAS;
        re = re_RAS;  
        
        matFileName = strrep(mriName, '.nii', '.mat');
        if exist(matFileName,'file')
            s = sprintf('Overwrite fiducials in existing .mat file?');
            response = questdlg(s,'MRI Co-registration','Yes','No','Yes');
            if strcmp(response,'No')
                return;
            end
        end
        
        % else save fiducials and update display and mat file
        fprintf('Saving Voxel to MEG coordinate transformation matrix and fiducials in %s\n', matFileName);
        save(matFileName, 'M', 'na','le','re','mmPerVoxel');
        
        % check for existing transform
        [mriDir,~,~] = fileparts(matFileName);
        transformFile = sprintf('%s%stransforms.mat', mriDir,filesep);

        if exist(transformFile,'file')
            s = sprintf('Update MEG to MNI transformation using current fiducials? (will overwrite existing files)');
            response = questdlg(s,'MRI Co-registration','Yes','No','Yes');
            if strcmp(response,'Yes')
                update_normalization_files;
                warndlg('** Existing Head Models (.hdm files) may need to be recalculated with new co-registration **');
            end
        end
        

    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % co-registration and normalization 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function import_freesurfer_Callback(~,~)
    
        if ~any(na_RAS) || ~any(le_RAS) || ~any(re_RAS)
            warndlg('You must first set locations for fiducials ...');
            return;
        end

        coreg_path =uigetdir('*','Select Freesurfer output directory...');
        if isequal(coreg_path,0)
            return;
        end    
        
        % check is freesurfer output
        if ~exist(fullfile(coreg_path, 'mri', 'transforms'), 'dir')
            errordlg('The selected folder does not appear to be a Freesurfer output folder');
            return;
        end
   
        [mri_dir,~,~] = fileparts(mriName);
        success = bw_importCoregistration(coreg_path, mri_dir, 'freesurfer');

        if success
            transforms = getMNITransforms;
            updateDisplay;
        end

    end

    function import_civet_Callback(~,~)
    
        if ~any(na_RAS) || ~any(le_RAS) || ~any(re_RAS)
            warndlg('You must first set locations for fiducials ...');
            return;
        end

        coreg_path =uigetdir('*','Select CIVET output directory...');
        if isequal(coreg_path,0)
            return;
        end    
        
        % check is freesurfer output
        if ~exist(fullfile(coreg_path, 'transforms'), 'dir')
            errordlg('The selected folder does not appear to be a Freesurfer output folder');
            return;
        end
   
        [mri_dir,~,~] = fileparts(mriName);
        success = bw_importCoregistration(coreg_path, mri_dir, 'civet');

        if success
            transforms = getMNITransforms;
            updateDisplay;
        end

    end

    function transforms = getMNITransforms
        
        transforms = [];

        [mri_path,~,~] = fileparts(mriName);
        transformsFile = sprintf('%s%stransforms.mat', mri_path,filesep);
        if ~exist(transformsFile,'file')
            fprintf('No transforms.mat file found in MRI directory...\n');
            return;
        end
        transforms = load(transformsFile);

    end

    function update_normalization_files

        % update transforms assuming fiducials have been changed and saved


        % get new MEG to RAS transformation from the .mat file
        matFileName = strrep(mriName, '.nii', '.mat');
        matfile = load(matFileName);
        meg2ras = inv(matfile.M);

        % ** note that transform matfile.M is RAS to MEG transform,
        % but does NOT include scaling MEG coords from cm to mm 
        % whereas the one in transforms.mat file does...

        scaleM = [10.0 0 0 0; 0 10.0 0 0; 0 0 10.0 0; 0 0 0 1];
        meg2ras = scaleM * meg2ras;

        if ~isempty(transforms)
            transforms.MEG_to_RAS = meg2ras;
            transforms.MNI_to_MEG = inv(transforms.RAS_to_MNI) * inv(transforms.MEG_to_RAS);   
            
            [mri_path,~,~] = fileparts(mriName);
            transformsFile = sprintf('%s%stransforms.mat',mri_path,filesep);
            fprintf('Saving updated affine transformations in %s\n', transformsFile);
            save(transformsFile,'-struct','transforms');     
        end

        % need to recreate the brain Hull shape from the brain mask
        % since it is in head coordinates.
        [mri_path,mri_name,~] = fileparts(mriName);
        maskFile = sprintf('%s%sbrainmask.nii',mri_path,filesep);

        if exist(maskFile,'file')
            
            % get the mask image
            nii = load_nii(maskFile);        
            % mask should match MRI resolution and dimensions!
            Img = nii.img;      
    
            % get RAS coordinates of non-zero voxels
            % and convert to MEG (head) coordinates
            idx = find(Img > 0);
            [x, y, z] = ind2sub( size(Img), idx);
            voxels = [x y z ones(size(x,1),1) ];
            headpts = voxels * inv(transforms.MEG_to_RAS);
            headpts(:,4) = [];
                
            fprintf('Creating convex hull from brain mask...\n');
    
            % create convex hull of brain mask in MEG coordinates
            points = double(headpts);
            idx = convhulln(points);
            headpts = points(idx,:);    
            shapefile = sprintf('%s%s%s_brainHull.shape',mri_path,filesep,mri_name);
      
            % get updated array size!
            npts = size(headpts,1);
            fprintf('writing %d points to shape file (%s)\n', npts, shapefile);
            fid = fopen(shapefile,'w');
            fprintf(fid, '%d\n', npts);
            for k=1:npts
                fprintf(fid,'%6.2f %6.2f  %6.2f\n', headpts(k,1), headpts(k,2), headpts(k,3));
            end
            fclose(fid);  
        end


    end

    % convert head points ** in mm ** to RAS and RPI voxels for drawing
    function [pts_RPI, pts_RAS] = Head_to_Voxels(pts_Head)
        
        % rotate from head coords into RAS
        vox2ctf = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);
        pts_RAS = round( [pts_Head ones(size(pts_Head,1),1)] * inv(vox2ctf) );
        pts_RAS(:,4) = [];
        
        % return in RPI for display
        pts_RPI(:,1) = pts_RAS(:,1)+1;
        pts_RPI(:,2) = slice_dim(2)-pts_RAS(:,2);
        pts_RPI(:,3) = slice_dim(3)-pts_RAS(:,3);                

    end


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Shape files and head models
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function open_CTFShapeCallback(~,~)
       [shapeFile, shapePath, ~] = uigetfile(...
            {'*.shape','CTF Shape File (*.shape)'},...
            'Select a head shape file');
        if shapeFile == 0
            return;
        end
        shapeFileName = [shapePath shapeFile];
        openShapeFile(shapeFileName);
    end

    function open_PolhemusCallback(~,~)
       [shapeFile, shapePath, ~] = uigetfile(...
            {'*.pos','CTF Polhemus file (*.pos)'},...
            'Select a head shape file');
        if shapeFile == 0
            return;
        end
        shapeFileName = [shapePath shapeFile];
        openShapeFile(shapeFileName);
    end
    function open_ChannelCallback(~,~)
       [shapeFile, shapePath, ~] = uigetfile(...
            {'*.mat','BrainStorm Channel file (*.mat)'},...
            'Select a head shape file');
        if shapeFile == 0
            return;
        end
        shapeFileName = [shapePath shapeFile];
        openShapeFile(shapeFileName);
    end
    function open_SFPCallback(~,~)
       [shapeFile, shapePath, ~] = uigetfile(...
            {'*.sfp','Surface point file (*.sfp)'},...
            'Select a head shape file');
        if shapeFile == 0
            return;
        end
        shapeFileName = [shapePath shapeFile];
        openShapeFile(shapeFileName);
    end

    function openShapeFile(shapeFileName)
    
        if ~any(na_RAS) || ~any(le_RAS) || ~any(re_RAS)
            warndlg('You must first set locations for fiducials ...');
            return;
        end

        shape_points=[];
        shape_points_RAS = [];        
        sphere_o=[];
        sphere_r=[];
        sphereList=[];  
        
        [~,~,ext] = fileparts(shapeFileName);
        tstr=sprintf('Shape File: %s',shapeFileName);
        set(WORKSPACE_TEXT_TITLE3,'string', tstr, 'enable','on','units','normalized','fontname','lucinda');
        switch ext
            case '.shape'
                fid = fopen(shapeFileName,'r');
                if fid == -1
                    error('Unable to open shape file.');
                end
                A = textscan(fid,'%s%s%s');
                fclose(fid);
                % points in CTF coords in cm...
                points = [str2double(A{1}(2:end)) str2double(A{2}(2:end)) str2double(A{3}(2:end))];    
            case {'.pos'}    
                [points, ~, ~, ~] = bw_readPolhemusFile(shapeFileName);  
            case '.sfp'
                [points,~, ~, ~] = bw_readSFPFile(shapeFileName); 
            case '.mat'
                [points,~, ~, ~] = bw_readChannelFile(shapeFileName);                 
            otherwise
                fprintf('Unsupported shape file format\n');
        end
        
        % here we assume we now have shape points in head coordinates in cm
        % that are aligned to current fiducials 
        % Head_to_Voxels expects shape data in mm

        shape_points = points(:,1:3) * 10.0;

        % convert from Head coordinates in mm to RAS and RPI voxels for display
        
        [shape_points_RPI, shape_points_RAS] = Head_to_Voxels(shape_points);
        updateDisplay;
                        
        if ~isempty(shape_points)
            set(FIT_MULTI_SPHERE, 'enable', 'on');
            set(FIT_SINGLE_SPHERE, 'enable', 'on');
            set(CLR_SHAPE, 'enable', 'on');
        end
        
        if template_val > 0 && ~isempty(shape_points)
            set(WARP_TEMPLATE,'enable','on');
        end
        
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % overlay controls
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    OVERLAY_BOX = annotation('rectangle',[0.5 .02 0.49 0.15],'visible','off');
    OVERLAY_LABEL = uicontrol('style','text','units','normalized','visible','off',...
        'position',[0.66 0.16 0.12 0.02],'String','Overlays','BackgroundColor','white','FontSize',9);

    % Latency slider for viewing overlay across multiple time points
    LATENCY_SLIDER = uicontrol('style','slider','units', 'normalized',...
        'position',[0.52 0.115 0.24 0.025],'min',0,'max',1,'Value',1,...
        'sliderStep', [1 1],'BackGroundColor', [0.9 0.9 0.9],'ForeGroundColor',...
        'white', 'visible', 'off', 'callback',@latency_Callback);

    latency_label = '';
    LATENCY_LABEL = uicontrol('style','text','units', 'normalized',...
        'position',[0.52 0.14 0.4 0.02],'FontSize',...
        9, 'HorizontalAlignment','left','BackGroundColor', 'white', 'visible', 'off', 'string','');

    function latency_Callback(src, ~)

         newVal = get(src,'Value');

         % update image
         imageNo = round(newVal);
         overlayFile = char(FILE_LIST(imageNo));
         
         loadOverlay(overlayFile);  % this loads and thresholds data, sets overlay.max
         
         set(CLEAR_OVERLAY,'enable','on');
         updateDisplay;

         % plot latency label
         [~, latency_label] = bw_get_latency_from_filename(overlayFile);
         set(LATENCY_LABEL, 'String',latency_label);
    end

COLORBAR_MAX_TEXT = uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
    [0.94 0.92 0.15 0.02],'string','1.0','fontsize',9,'FontWeight','normal','background','white','visible','off');
COLORBAR_MIN_TEXT = uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
    [0.935 0.56 0.15 0.02],'string','-1.0','fontsize',9,'FontWeight','normal','background','white','visible','off');

MAX_SCALE_TEXT = uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
    [0.83 0.075 0.1 0.02],'string','Max. Scale:','fontsize',9,'FontWeight','normal','background','white','visible','off');

MAX_SCALE_EDIT = uicontrol('style','edit','units','normalized','position',...
    [0.92 0.07 0.05 0.03],'String', '0.0',...
    'FontSize', 9, 'BackGroundColor','white', 'visible', 'off', 'callback',@max_scale_edit_callback);

    function max_scale_edit_callback(src,~)
        t = str2double(get(src,'String'));
        
        overlay.max = abs(t);
        
        overlay.image = overlay.data;
        idx = find( abs(overlay.image) < overlay.threshold * overlay.max);
        overlay.image(idx) = NaN;   
        
        s = sprintf('%.2f', overlay.max);
        set(COLORBAR_MAX_TEXT, 'string',s);
        s = sprintf('%.2f', -overlay.max);
        set(COLORBAR_MIN_TEXT, 'string',s);
        
         % update display
         updateDisplay;    
    end

THRESHOLD_TEXT = uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
    [0.52 0.075 0.15 0.02],'string','Threshold (%):','fontsize',9,'FontWeight','normal','background','white','visible','off');

THRESHOLD_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.68 0.075 0.13 0.025],'min',0,'max',1,...
    'Value',defaultThreshold, 'sliderStep', [0.01 0.05],'BackGroundColor',...
    [0.9 0.9 0.9], 'visible', 'off', 'callback',@threshold_slider_Callback);

THRESH_EDIT = uicontrol('style','edit','units','normalized','position',...
    [0.62 0.07 0.05 0.03],'String', '0.0',...
    'FontSize', 9, 'BackGroundColor','white', 'visible', 'off', 'callback',@thresh_edit_callback);

    function thresh_edit_callback(src,~)
        t = str2double(get(src,'String'));
        thresh = t * 0.01;
        % if input exceeds max threshold, set to max
        if thresh > 1.0
            thresh = 1.0;
            s = sprintf('%0.2f', thresh * 100.0);
            set(src, 'String', s);
        end
        if thresh < 0.0
            thresh = 0.0;
            s = sprintf('%0.2f', thresh * 100.0);
            set(src, 'String', s);
        end
        
        overlay.threshold = thresh;
        
        % threshold current image to new value
        overlay.image = overlay.data;
        idx = find( abs(overlay.image) < overlay.threshold * overlay.max);
        overlay.image(idx) = NaN;
        
        set(THRESHOLD_SLIDER, 'Value', overlay.threshold);

        % update display
        updateDisplay;
    end

    function threshold_slider_Callback(src, ~)
        if isempty(overlay)
            return;
        end
        overlay.threshold = get(src,'Value'); 

        % threshold to new value
        overlay.image = overlay.data;
        idx = find( abs(overlay.image) < overlay.threshold * overlay.max);
        overlay.image(idx) = NaN;
              
        thresh_str = sprintf('%.2f', overlay.threshold * 100.0);
        set(THRESH_EDIT, 'String', thresh_str);
        
        updateDisplay;
    end

TRANSPARENCY_TEXT = uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
    [0.52 0.035 0.15 0.02],'string','Opacity:','fontsize',9,'FontWeight','normal','background','white','visible','off');

TRANSPARENCY_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.68 0.032 0.13 0.025],'min',0,'max',1,...
    'Value',1.0, 'sliderStep', [0.01 0.05],'BackGroundColor',...
    [0.9 0.9 0.9], 'visible', 'off', 'callback',@transparency_slider_Callback);

TRANSPARENCY_EDIT = uicontrol('style','edit','units','normalized','position',...
    [0.62 0.03 0.05 0.03],'String', '0.0',...
    'FontSize', 10, 'BackGroundColor','white', 'visible', 'off', 'callback',@transparency_edit_callback);

    function transparency_edit_callback(src,~)
        t = str2double(get(src,'String'));
        thresh = t;
        % if input exceeds max threshold, set to max
        if thresh > 1.0
            thresh = 1.0;
            s = sprintf('%0.2f', thresh);
            set(src, 'String', s);
        end
        if thresh < 0.0
            thresh = 0.0;
            s = sprintf('%0.2f', thresh);
            set(src, 'String', s);
        end
        
        overlay.transparency = thresh;
        
        set(TRANSPARENCY_SLIDER, 'Value', overlay.transparency);

        % update display
        updateDisplay;
    end

    function transparency_slider_Callback(src, ~)
        if isempty(overlay)
            return;
        end
        overlay.transparency = get(src,'Value'); 
        
        thresh_str = sprintf('%.2f', overlay.transparency);
        set(TRANSPARENCY_EDIT, 'String', thresh_str);
        
        updateDisplay;
    end

    FIND_MAX_Button = uicontrol('style','pushbutton','units','normalized','Position',...
        [0.83 0.03 0.07 0.03],'String','Find Max','BackgroundColor','white','visible','off',...
        'FontSize',9,'callback',@find_max_callback);
    
    FIND_MIN_Button = uicontrol('style','pushbutton','units','normalized','Position',...
        [0.91 0.03 0.07 0.03],'String','Find Min','BackgroundColor','white','visible','off',...
        'FontSize',9,'callback',@find_min_callback);

    function find_max_callback(~, ~)
        if isempty(overlay)
            return;
        end

        [vox_ras, ~, ~, ~] = findOverlayPeak;
        
        oldcoords=[vox_ras(1),vox_ras(2),vox_ras(3)];
        updateDisplay;

        slice1_RAS = oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', slice1_RAS+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-slice2_RAS);
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-slice3_RAS);
        
        oldcoords=[vox_ras(1),vox_ras(2),vox_ras(3)];
        updateDisplay;
                
    end

    function find_min_callback(~, ~)
        if isempty(overlay)
            return;
        end

        [~, ~, vox_ras, ~] = findOverlayPeak;
        
        oldcoords=[vox_ras(1),vox_ras(2),vox_ras(3)];

        updateDisplay;
        
        slice1_RAS = oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', slice1_RAS+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-slice2_RAS);
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-slice3_RAS);
        
        oldcoords=[vox_ras(1),vox_ras(2),vox_ras(3)];
        updateDisplay;
                
    end

    function gotoMEG_callback(~,~) 
          
        input = inputdlg({'MEG coordinate (cm)'},'Find MEG Coordinate', [1 50], {num2str(meg_coord)});
        if isempty(input)
            return;
        end
        meg_coord = str2num(input{1});     
            
        matFileName = strrep(mriName, '.nii', '.mat');
        matfile = load(matFileName);
        meg2ras = inv(matfile.M);  % matfile.M is RAS to MEG
             
        transforms = getMNITransforms;
        if isempty(transforms)
            return;
        end

        % note if we use M matrix it does not including scale from cm

        vox_ras =  round( [meg_coord 1] * transforms.MEG_to_RAS );
        vox_ras(4) = [];
                
        if vox_ras(1) < 1 || vox_ras(1) > slice_dim(1) || vox_ras(2) < 1 || vox_ras(2) > slice_dim(2) || vox_ras(3) < 1 || vox_ras(3) > slice_dim(3)
            fprintf('Voxel out of image bounds...\n');
            return;
        end
        
        oldcoords=[vox_ras(1),vox_ras(2),vox_ras(3)];
        updateDisplay;
        
        slice1_RAS = oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', slice1_RAS+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-slice2_RAS);
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-slice3_RAS);
                
        oldcoords=[vox_ras(1),vox_ras(2),vox_ras(3)];
        updateDisplay;      
    end

    function gotoMNI_callback(~,~) 
          
        input = inputdlg({'MNI coordinate (mm)'},'Find MNI Coordinate', [1 50], {num2str(mni_coord)});
        if isempty(input)
            return;
        end
        mni_coord = str2num(input{1});
              
        transforms = getMNITransforms;
        if isempty(transforms)
            return;
        end
        vox_ras =  round( [mni_coord 1] * inv(transforms.RAS_to_MNI) );
        vox_ras(4) = [];
                
        if vox_ras(1) < 1 || vox_ras(1) > slice_dim(1) || vox_ras(2) < 1 || vox_ras(2) > slice_dim(2) || vox_ras(3) < 1 || vox_ras(3) > slice_dim(3)
            fprintf('Voxel out of image bounds...\n');
            return;
        end
        
        oldcoords=[vox_ras(1),vox_ras(2),vox_ras(3)];
        updateDisplay;
        
        slice1_RAS = oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', slice1_RAS+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-slice2_RAS);
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-slice3_RAS);
                
        oldcoords=[vox_ras(1),vox_ras(2),vox_ras(3)];
        updateDisplay;       
    end

    function open_overlay_callback(~,~)
           
            [names, pathname, ~]=uigetfile('*.svl','SAM Volume (*.svl)',...
                'Select image files...', 'MultiSelect','on');            
            if isequal(names,0)
                return;
            end                

            names = cellstr(names);   % force single file to be cellstr
            filenames = strcat(pathname,names);      % prepends path to all instances
            overlayFiles = cellstr(filenames);

            loadOverlays(overlayFiles);
    end

    function open_mni_overlay_callback(~,~)
           
            [names, pathname, ~]=uigetfile('*.nii','Normalized NIfTI (w*.nii)',...
                'Select image files...', 'MultiSelect','on');            
            if isequal(names,0)
                return;
            end                

            names = cellstr(names);   % force single file to be cellstr
            filenames = strcat(pathname,names);      % prepends path to all instances
            overlayFiles = cellstr(filenames);

            loadMNIOverlays(overlayFiles);
    end

    function open_mask_overlay_callback(~,~)
           
            [name, pathname, ~]=uigetfile('*.nii','Select mask file...');            
            if isequal(name,0)
                return;
            end                
            maskFile = [pathname name];

            % get the mask image and resolution
            nii = load_nii(maskFile);
            
            fprintf('loading MASK file %s ...\n', maskFile);
            overlayFile = maskFile;
            s=sprintf('Overlay: %s', overlayFile);       
            set(WORKSPACE_TEXT_TITLE3,'string', s, 'enable','on');
            
            % mask should match MRI resolution and dimensions!
            Img = nii.img; 
            
            % put mask image in RPI orientation for drawing routines...
                  
            % flip z direction RAS -> RAI
            img2 = flipdim(Img,3);
            % flip y direction RAI -> RPI
            maskOverlay.image = flipdim(img2,2);
            clear img2;
         
            % get masked out voxels (= 0)
            zeroVox = find(maskOverlay.image == 0);
            
            % scale here once to overlay colour map 0.3 = yellow
            maskOverlay.image(:) = (0.3)*64.0+(128+64);
            maskOverlay.image(zeroVox) = NaN;
                       
            set(TRANSPARENCY_SLIDER, 'visible', 'on');
            set(TRANSPARENCY_TEXT, 'visible', 'on');
            set(TRANSPARENCY_EDIT, 'visible', 'on');  

            overlay.transparency = 0.4;
            set(TRANSPARENCY_SLIDER, 'Value', overlay.transparency);
            set(TRANSPARENCY_EDIT, 'String', overlay.transparency);
        
            updateDisplay;

                    
            set(CLEAR_OVERLAY,'enable','on');

    end


    function loadOverlays(overlayFiles)

            shape_points=[];
            shape_points_RAS = [];
            surface_points=[];        
            surface_faces=[];
            sphere_o=[];
            sphere_r=[];
            sphereList=[];

            FILE_LIST = {};
            numFiles = numel(overlayFiles);
            latencies = zeros(numFiles,1);

            % get latencies from filename and sort according to latency
            for k=1:numFiles
                thisFile = char( overlayFiles(k) );
                [t, ~] = bw_get_latency_from_filename(thisFile);
                if ~isnan(t)
                   latencies(k) = t;
                end
            end

            % if possible try to sort files according to latency
            if ~isempty(latencies)
                tlist = [(1:1:numFiles)' latencies];
                slist = sortrows(tlist,2);
                idx = round(slist(:,1));
                for k=1:numFiles
                    FILE_LIST(k) = overlayFiles(idx(k));
                end
            else
                    FILE_LIST(k) = overlayFiles;
            end
            
            % show slider if more than one file selected

            % calculate global max (use in thresholding)
            global_min = 1e12;
            global_max = -1e12;

            overlay.threshold = defaultThreshold;
            set(THRESHOLD_SLIDER,'value',overlay.threshold);
            s = sprintf('%.1f',overlay.threshold * 100);
            set(THRESH_EDIT,'string',s);      
            
            % get global max 
            for k=1:numFiles
                tfile = char(FILE_LIST(k));
                svl = bw_readSvlFile( tfile );
                data = svl.Img;
                    
                minVal = min(min(min(data)));
                if minVal < global_min
                    global_min = minVal;
                end

                maxVal = max(max(max(data)));
                if maxVal > global_max
                    global_max = maxVal;
                end
            end
           
            if abs(global_min) > global_max
                global_max = abs(global_min);
            end        
            
            set(LATENCY_SLIDER,'visible','on');
            step(1:2) = 1/numFiles;
            % make single step - fix for no scroll arrows on OS X Lion
            if numFiles > 1
                set(LATENCY_SLIDER,'visible','on');
                step(2) = 1/numFiles * 5;
            else
                set(LATENCY_SLIDER,'visible','off');
            end
            
            overlayFile = char(FILE_LIST(1));
            [~, latency_label] = bw_get_latency_from_filename(overlayFile);

            set(LATENCY_SLIDER,'min',1,'max',numFiles,'Value',1,'sliderStep',step);
            set(LATENCY_LABEL, 'String',latency_label);
            set(LATENCY_LABEL, 'visible', 'on');

            % display first overlay file selected
            loadOverlay(overlayFile);
            find_max_callback;

            enable_overlay_controls('on');

    end

    % file type switch doesn't work on MacOS - need separate menu
    function loadMNIOverlays(overlayFiles)

            shape_points=[];
            shape_points_RAS = [];
            surface_points=[];        
            surface_faces=[];
            sphere_o=[];
            sphere_r=[];
            sphereList=[];

            FILE_LIST = {};
            numFiles = numel(overlayFiles);
            latencies = zeros(numFiles,1);

            % get latencies from filename and sort according to latency
            for k=1:numFiles
                thisFile = char( overlayFiles(k) );
                [t, ~] = bw_get_latency_from_filename(thisFile);
                if ~isnan(t)
                   latencies(k) = t;
                end
            end

            % if possible try to sort files according to latency
            if ~isempty(latencies)
                tlist = [(1:1:numFiles)' latencies];
                slist = sortrows(tlist,2);
                idx = round(slist(:,1));
                for k=1:numFiles
                    FILE_LIST(k) = overlayFiles(idx(k));
                end
            else
                    FILE_LIST(k) = overlayFiles;
            end
            
            % show slider if more than one file selected

            % calculate global max (use in thresholding)
            global_min = 1e12;
            global_max = -1e12;

            overlay.threshold = defaultThreshold;
            set(THRESHOLD_SLIDER,'value',overlay.threshold);
            s = sprintf('%.1f',overlay.threshold * 100);
            set(THRESH_EDIT,'string',s);      
            
            % get global max 
            for k=1:numFiles
                tfile = char(FILE_LIST(k));   
                nii = load_nii(tfile);
                data = nii.img;            
                    
                minVal = min(min(min(data)));
                if minVal < global_min
                    global_min = minVal;
                end

                maxVal = max(max(max(data)));
                if maxVal > global_max
                    global_max = maxVal;
                end
            end
           
            if abs(global_min) > global_max
                global_max = abs(global_min);
            end        
            
            set(LATENCY_SLIDER,'visible','on');
            step(1:2) = 1/numFiles;
            % make single step - fix for no scroll arrows on OS X Lion
            if numFiles > 1
                set(LATENCY_SLIDER,'visible','on');
                step(2) = 1/numFiles * 5;
            else
                set(LATENCY_SLIDER,'visible','off');
            end
            
            overlayFile = char(FILE_LIST(1));
            [~, latency_label] = bw_get_latency_from_filename(overlayFile);

            set(LATENCY_SLIDER,'min',1,'max',numFiles,'Value',1,'sliderStep',step);
            set(LATENCY_LABEL, 'String',latency_label);
            set(LATENCY_LABEL, 'visible', 'on');
            
            % display first overlay file selected
            loadOverlay(overlayFile);
            updateDisplay;
            find_max_callback;


            enable_overlay_controls('on');

    end



    function enable_overlay_controls(str)
            set(FIND_MAX_Button, 'visible',str);
            set(FIND_MIN_Button, 'visible',str);
            set(THRESHOLD_SLIDER, 'visible', str);
            set(THRESHOLD_TEXT, 'visible', str);
            set(OVERLAY_BOX, 'visible', str);
            set(OVERLAY_LABEL, 'visible', str);
            set(MAX_SCALE_TEXT,'visible',str);
            set(MAX_SCALE_EDIT,'visible',str);
            set(COLORBAR_MAX_TEXT,'visible',str);
            set(COLORBAR_MIN_TEXT,'visible',str);
            
            set(LATENCY_LABEL, 'visible', str);
            set(LATENCY_SLIDER, 'visible', str);
            set(THRESH_EDIT, 'visible', str);
            set(TRANSPARENCY_SLIDER, 'visible', str);
            set(TRANSPARENCY_TEXT, 'visible', str);
            set(TRANSPARENCY_EDIT, 'visible', str);  
            set(c_bar(:),'visible',str);
            set(CLEAR_OVERLAY,'enable',str);
    end


    function loadOverlay(overlayFile)

            [~, ~, ext] = fileparts(overlayFile);

            if strcmp(ext,'.svl')
           
                % fprintf('Loading SAM Volume (.svl) overlay file %s...\n', overlayFile);
                % read svl
                svl = bw_readSvlFile(overlayFile);
    
                overlay.data = svl.Img; % image is x, y, z
                overlay.data= permute(overlay.data, [3 2 1]); % transpose from z y x to x y z

                overlay.max = max(max(max( abs(overlay.data) )));
                min_val = min(min(min( overlay.data)));

                xyz = size(overlay.data);
                overlay.DIM(1) = xyz(1);
                overlay.DIM(2) = xyz(2);
                overlay.DIM(3) = xyz(3);
                overlay.RES(1) = svl.mmPerVoxel;
                overlay.RES(2) = svl.mmPerVoxel;
                overlay.RES(3) = svl.mmPerVoxel;
                overlay.bb = svl.bb * 10.0; % in mm
                
                % make thresholded copy, don't erase original image
                overlay.image = overlay.data;  
                idx = find(abs(overlay.image) < overlay.threshold * overlay.max);
                overlay.image(idx) = NaN;
                overlay.imageType = 'CTF';
  
            elseif strcmp(ext,'.nii')
                % fprintf('Loading MNI Volume (.nii) overlay file %s...\n', overlayFile);
                nii = load_nii(overlayFile);
                voxelSize = nii.hdr.dime.pixdim(2);

                % create a default .svl volume and set to NaN
                defaults = bw_setDefaultParameters;
                bb = defaults.beamformer_parameters.boundingBox;  
                stepSize = defaults.beamformer_parameters.stepSize; 
                xdim = round( ( (bb(2)-bb(1)) / stepSize ) + 1);
                ydim = round( ( (bb(4)-bb(3)) / stepSize ) + 1);
                zdim = round( ( (bb(6)-bb(5)) / stepSize ) + 1);                               

                % get MNI voxels

                transforms = getMNITransforms;
                if isempty(transforms)
                    return;
                end

                % % interpolation method 
                % % interpolate from MNI to .svl space - not needed since
                % drawing routine does coordinate system conversion.
                %
                % ctf_coords = bw_createNormalizedVoxels(transforms.MNI_to_MEG, SPM_BB, voxelSize);
                % v = nii.img(:);
                % 
                % % interpolate into regular grid (.svl volume) 
                % fprintf('interpolating MNI image to CTF volume...\n')
                % F = scatteredInterpolant(ctf_coords,v);
                % xcoords = linspace(bb(1), bb(2),xdim);  % use linspace to force number of voxels to match
                % ycoords = linspace(bb(3), bb(4),ydim);  
                % zcoords = linspace(bb(5), bb(6),zdim);  
                % [x, y, z] = meshgrid(xcoords,ycoords,zcoords);
                % newImg = F(x,y,z);
                % newImg = permute(newImg,[2,1,3]);   
                % 
                % overlay.data = newImg;
                % 
                % 
                % newImg = permute(newImg,[2,1,3]);   
                % 
                % overlay.max = max(max(max( abs(overlay.data) )));
                % min_val = min(min(min( overlay.data)));
                % 
                % xyz = size(overlay.data);
                % overlay.bb = bb * 10.0;          
                % overlay.DIM(1) = xyz(1);
                % overlay.DIM(2) = xyz(2);
                % overlay.DIM(3) = xyz(3);
                % 
                % overlay.RES(1) = stepSize * 10.0;
                % overlay.RES(2) = stepSize * 10.0;
                % overlay.RES(3) = stepSize * 10.0;

                % exchange x and y
                overlay.data = permute(nii.img,[2,1,3]);   
                overlay.data = nii.img;

                overlay.max = max(max(max( abs(overlay.data) )));
                min_val = min(min(min( overlay.data)));

                xyz = size(overlay.data);
                overlay.DIM(1) = xyz(1);
                overlay.DIM(2) = xyz(2);
                overlay.DIM(3) = xyz(3);
                overlay.bb = [SPM_BB(1) SPM_BB(4) SPM_BB(2) SPM_BB(5) SPM_BB(3) SPM_BB(6)];          

                overlay.RES(1) = voxelSize;
                overlay.RES(2) = voxelSize;
                overlay.RES(3) = voxelSize;

                % make thresholded copy, don't erase original image
                overlay.image = overlay.data;  
                idx = find(abs(overlay.image) < overlay.threshold * overlay.max);
                overlay.image(idx) = NaN;
                overlay.imageType = 'MNI';

            end

            overlay.transparency = get(TRANSPARENCY_SLIDER,'value');
            s = sprintf('%.2f', overlay.max);
            set(MAX_SCALE_EDIT, 'string',s);
            set(COLORBAR_MAX_TEXT, 'string',s);
            s = sprintf('%.2f', -overlay.max);
            set(COLORBAR_MIN_TEXT, 'string',s);
            
            enable_overlay_controls('on');            
            if min_val < 0.0
                set(FIND_MIN_Button,'enable','on');
            else
                set(FIND_MIN_Button,'enable','off');
            end

            [~,n,e] = fileparts(overlayFile);
            s=sprintf('Overlay: %s', [n e]);      

            set(WORKSPACE_TEXT_TITLE3,'string', s, 'enable','on');


    end

    function [max_ras, max_ctf, min_ras, min_ctf] = findOverlayPeak

            max_ras = [];
            max_ctf = [];
            
            min_ras = [];
            min_ctf = [];
            
            if isempty(overlay)
                return;
            end
            
            % get peaks
            [~, idx] = max( overlay.data(:) );
            dims = size(overlay.data);
            [x, y, z] = ind2sub(dims,idx);
            
            [~, idx] = min( overlay.data(:));
            dims = size(overlay.data);
            [x2, y2, z2] = ind2sub(dims,idx);            
         
            if strcmp(overlay.imageType,'CTF')
                vox2ctf = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel );  
                M = inv(vox2ctf);
            else                              
                transforms = getMNITransforms;
                M = inv(transforms.RAS_to_MNI);  
            end

            max_ctf(1) = overlay.bb(1) + ( (x-1) * overlay.RES(1) );
            max_ctf(2) = overlay.bb(3) + ( (y-1) * overlay.RES(2) ) ;
            max_ctf(3) = overlay.bb(5) + ( (z-1) * overlay.RES(3) );
            max_ras =  round( [max_ctf 1] * M);
            max_ras(4) = [];
                        
            min_ctf(1) = overlay.bb(1) + ( (x2-1) * overlay.RES(1) );
            min_ctf(2) = overlay.bb(3) + ( (y2-1) * overlay.RES(2) ) ;
            min_ctf(3) = overlay.bb(5) + ( (z2-1) * overlay.RES(3) );
            min_ras =  round( [min_ctf 1] * M);
            min_ras(4) = [];

    end

function open_sensorsCallback(~,~)
           
        ds_fullname=uigetdir('Select Dataset ...');
        if ds_fullname == 0
            return;
        end
        
        sensor_points = [];
        sensor_points_RPI = [];

        [~, pts, ~] = bw_CTFGetSensors(char(ds_fullname), 0);
        sensor_points = pts * 10.0;
        
        % convert to voxels for display
        
        coord_x=sensor_points(:,1);
        coord_y=sensor_points(:,2);
        coord_z=sensor_points(:,3);
        nnn=length(coord_x);
        
        na_RPI = [na_RAS(1)+1 slice_dim(2)-na_RAS(2) slice_dim(3)-na_RAS(3)];
        le_RPI = [le_RAS(1)+1 slice_dim(2)-le_RAS(2) slice_dim(3)-le_RAS(3)];
        re_RPI = [re_RAS(1)+1 slice_dim(2)-re_RAS(2) slice_dim(3)-re_RAS(3)];
        Transform_M = bw_getTransformMatrix(na_RPI, le_RPI, re_RPI);
        MM = Transform_M*[coord_x'/mmPerVoxel;coord_y'/mmPerVoxel;coord_z'/mmPerVoxel;ones(1,nnn)];
        shape_vox_x = round(MM(1,:)');
        shape_vox_y = round(MM(2,:)');
        shape_vox_z = round(MM(3,:)');
        sensor_points = [shape_vox_x-1 slice_dim(2)-shape_vox_y slice_dim(3)-shape_vox_z];

        sensor_points_RPI(:,1) = sensor_points(:,1)+1;   
        sensor_points_RPI(:,2) = slice_dim(2)-sensor_points(:,2);
        sensor_points_RPI(:,3) = slice_dim(3)-sensor_points(:,3);        
        
        updateDisplay;     
        
        set(CLEAR_OVERLAY,'enable','on');

end


function open_dipCallback(~,~)
                 
        if ~any(na_RAS) || ~any(le_RAS) || ~any(re_RAS)
            warndlg('You must first set locations for fiducials ...');
            return;
        end
        
        [name, path, ~] = uigetfile(...
            {'*.dip','Dipole file(Head coordinate)(*.dip)'},...
            'Select a dipole file');
        
        Dip_File = fullfile(path,name);
        if Dip_File == 0
            return;
        end
        
        loadDipoleFile(Dip_File) 
        
end

function loadDipoleFile(dipoleFile)    
    
    
    new_params = bw_readCTFDipoleFile(dipoleFile);

    if ~isempty(dip_params)
        r = questdlg('Replace or add to current dipole list?','Dipole Overlay','Replace','Add','Replace');
        if strcmp(r,'Replace')
            dip_params = new_params;
        else
            dip_params = [dip_params; new_params];
        end
    else
        dip_params = new_params;
    end

    tstr=sprintf('Dipole File: %s',dipoleFile);
    set(WORKSPACE_TEXT_TITLE3,'string', tstr, 'enable','on');

    % convert to voxel space
    % need to rotate orientation vectors only

    [dip_params_RPI, ~] = Head_to_Voxels( dip_params(:,1:3)*10.0 );

    % rotate dipole orientations to RPI
    dip_orient_RPI = [];
    na_RPI = [na_RAS(1)+1 slice_dim(2)-na_RAS(2) slice_dim(3)-na_RAS(3)];
    le_RPI = [le_RAS(1)+1 slice_dim(2)-le_RAS(2) slice_dim(3)-le_RAS(3)];
    re_RPI = [re_RAS(1)+1 slice_dim(2)-re_RAS(2) slice_dim(3)-re_RAS(3)];
    vox2ctf = bw_getAffineVox2CTF(na_RPI, le_RPI, re_RPI, mmPerVoxel);
    ctf2vox = inv(vox2ctf);
    rotM = ctf2vox(1:3,1:3);
    vec = dip_params(:,4:6);
    dip_orient_RPI = vec * rotM;

    tail_show = 1;

    for k=1:size(dip_params,1)
        str{k} = sprintf('Dipole %d',k);
    end     
    set(dipoleMenu,'string',str);
    set(dipoleMenu,'visible','on');
    set(showDipoleCheck, 'visible', 'on');

    currentDip = size(dip_params,1);
    set(dipoleMenu,'value',currentDip);       

    goToDipole(currentDip);                
    set(CLEAR_OVERLAY,'enable','on');       
 

end

function clear_overlayCallback( ~,~ )

    sensor_points = [];
    sensor_points_RPI = [];
    sphere_o=[];
    sphere_r=[];
    sphereList=[];
    surface_points=[];      
    surface_faces=[];        
    sensor_points = [];
    dip_params = [];
    dip_params_RPI = [];

    if ~isempty(overlay.image)
        overlay.image = [];
    end

    if ~isempty(maskOverlay.image)
        maskOverlay.image = [];
    end    
    
    updateDisplay;
    
    enable_overlay_controls('off');
    set(dipoleMenu, 'visible', 'off');
    set(showDipoleCheck, 'visible', 'off');
    
    set(WORKSPACE_TEXT_TITLE2, 'String', 'Surface File:');
    set(WORKSPACE_TEXT_TITLE3, 'String', 'Shape File');

end

dipoleMenu = uicontrol('style','popup','units','normalized','Position',...
    [0.88 0.105 0.1 0.03],'String','none','BackgroundColor','white',...
    'FontSize',9,'ForegroundColor','black','visible','off','callback',@dipoleMenuCallback);

    function dipoleMenuCallback(src,~)
        currentDip = get(src,'value');
        goToDipole(currentDip);
    end
        
    function goToDipole(currentDip)
        
        if isempty(dip_params_RPI)
            return;
        end
                
        oldcoords_RPI = dip_params_RPI(currentDip,:);
        oldcoords = [oldcoords_RPI(1)-1 slice_dim(2)-oldcoords_RPI(2) slice_dim(3)-oldcoords_RPI(3)];
        
        slice1_RAS=oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', slice1_RAS+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-slice2_RAS);
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3));
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-slice3_RAS);

        updateDisplay;

    end

    showDipoleCheck = uicontrol('style','checkbox','units','normalized','Position',...
        [0.885 0.14 0.1 0.03],'String','Show All','BackgroundColor','white',...
        'FontSize',9,'ForegroundColor','black','visible','off','callback',@showDipoleCheckCallback);

    function showDipoleCheckCallback(src,~)
        showAllDipoles = get(src,'value');
        goToDipole(currentDip);
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% surfaces 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    function clear_surfaceCallback( ~,~ )
        
        surface_points = [];
        set(WORKSPACE_TEXT_TITLE2,'string', 'Surface File:');
        updateDisplay;

        set(CLR_SURFACE, 'enable', 'off');
    end

    function clear_shapeCallback( ~,~ )
        
        shape_points = [];
        shape_points_RAS = [];
        shape_points_RPI = [];
       
        set(WORKSPACE_TEXT_TITLE3,'string', 'Shape File:');
        updateDisplay;
        
        set(FIT_SINGLE_SPHERE,'enable','off');
        set(FIT_MULTI_SPHERE,'enable','off');
        set(CLR_SHAPE, 'enable', 'off');
    end
 
    % move to controls on main window ..
    function extract_surfaceCallback(~,~)
                                
        input = inputdlg({'Intensity Threshold (%)'; 'Surface resolution (mm)'},...
            'Surface Extraction Parameters',[1 50; 1 50], {num2str(surfaceThreshold),num2str(surfaceResolution)});
        if isempty(input)
            return;
        end   
        surfaceThreshold = str2double(input{1});
        surfaceResolution = str2double(input{2});
        updateSurface;

    end

    function updateSurface

        surface_points=[];
        surface_faces=[];   
        surface_points_RPI = [];

        surface_points = extract_MRI_surface(surfaceThreshold, surfaceResolution)'; 
                
        % flip from RAS to RPI and increment to 1 to 256
        % *** assumes input is 0 to 255 ***
        surface_points_RPI(:,1) = surface_points(:,1)+1;   
        surface_points_RPI(:,2) = slice_dim(2)-surface_points(:,2);
        surface_points_RPI(:,3) = slice_dim(3)-surface_points(:,3);
        
        surface_points_orien_RPI = [];  % don't draw normals since this is not a mesh...
        
        updateDisplay;
        
        if ~isempty(surface_points)
            set(CLR_SURFACE, 'enable', 'on');       
            set(DEFACE_MENU,'enable','on');
         end
        
    end

    function [mri_shape_points] = extract_MRI_surface(threshold_percent, resolution)

        % erosion method to get MRI skin surface from currently loaded MRI
        image = img_RAS;

        if exist('threshold_percent','var')
            thresh_ratio = threshold_percent * 0.01;
        else
            thresh_ratio = 0.2;
        end
        
        % convert step size in mm to voxels
        if exist('resolution','var')
            stepSize = round(resolution / mmPerVoxel);
        else
            stepSize = 4;
        end
        mx=max(max(max(max(image))),1);
        threshold = mx * thresh_ratio;              

        length_x = slice_dim(1);
        length_y = slice_dim(2);
        length_z = slice_dim(3);

        step_x = stepSize;  
        step_y = stepSize;
        step_z = stepSize;       

        % erode from different directions in stepSize increments.
        % Faster method than using for loop, use find() to find first and
        % last pixel value > threshold in each column,
        % don't scan from bottom up in z direction
 
        % transform head shape to voxels using current fids
        
        tic
        % Z: scan down from top only
        % ** removed for better surface extraction
        zscan = [];
        fprintf('Scanning in z direction...\n');
        for x=1:step_x:length_x  
            for y = 1:step_y:length_y  
                z = image(x,y,:);
                t = find(z > threshold);
                if ~isempty(t)
                    zscan(end+1,:) = [x y t(end)]; 
                end
            end
        end
         
        % Y: scan anterior - posterior direction
        yscan = [];
        fprintf('Scanning in y direction...\n');
        for x=1:step_x:length_x 
            for z = 1:step_z:length_z 
                y = image(x,:,z);
                t = find(y > threshold);
                if ~isempty(t)
                    yscan(end+1,:) = [x t(1)-1 z];
                    yscan(end+1,:) = [x t(end) z];
                end
            end
        end

        % X: scan left - right
        xscan = [];
        fprintf('Scanning in x direction...\n');
        for y=1:step_y:length_y 
            for z = 1:step_z:length_z  
                x = image(:,y,z);
                t = find(x > threshold);
                if ~isempty(t)
                    xscan(end+1,:) = [t(1)-1 y z];
                    xscan(end+1,:) = [t(end) y z];
                end
            end
        end
        toc
        
        mri_shape_points = [xscan; yscan; zscan];
        
        if ~isempty(mri_shape_points)   
           mri_shape_points = unique(mri_shape_points,'rows')'; 
           clear tpts;
        end
        
        fprintf('... done\n');
        clear head_shape_RAS

    end

    function view_surfaceCallback( ~,~ )
        if ~isempty(surface_points)
            surface = create_surface_mesh(surface_points);    
            viewSurface(surface);
        else
            viewSurface;
        end        
    end
        
    function deface_optCallback(~,~)   
        
        % restore image
        if isempty(img_RAS_original)
            img_RAS_original = img_RAS;
        else
            img_RAS = img_RAS_original;
        end
        
        deface_dialog;  % get bounding box etc...
        
        if enable_defacing  
            fprintf('defacing volume ...  ');
            vox2head = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);   

            for i=1:slice_dim(1)
                 for j=1:slice_dim(2)
                    for k = 1:slice_dim(3)
                         meg_pos =  [i j k 1] * vox2head;
                         % if in defacing volume set to zero
                         if meg_pos(1) > deface_bb(1) && meg_pos(1) < deface_bb(2) && ...
                                 meg_pos(2) > deface_bb(3) && meg_pos(2) < deface_bb(4) && ...
                                 meg_pos(3) > deface_bb(5) && meg_pos(3) < deface_bb(6)
                                        img_RAS(i, j, k) = 0;  
                         end
                     end
                end
            end
             fprintf(' done\n');
           
        end
        
        % reset display image
        img2 = flipdim(img_RAS,3);
        % flip y direction RAI -> RPI
        img = flipdim(img2,2);
        
        if(mri_nii.hdr.dime.datatype==2)
            img_display1=uint8(img);
        else
            maxVal = max(max(max(img)));
            maxVal = double(maxVal);
            scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
            img_display1 = scaleTo8bit* img; 
            img_display1 = uint8(img_display1);
        end
        clear img2;
        
        updateDisplay;
        
    end

    function deface_dialog()
        
        scrsz=get(0,'ScreenSize');
        f2=figure('Name', 'Defacing Volume', 'Position', [(scrsz(3)-650)/2 (scrsz(4)-300)/2 650 300],...
            'menubar','none','numbertitle','off', 'color','white');
        
        uicontrol('style','checkbox','units', 'normalized',...
            'position',[0.05 0.75 0.4 0.2],'String','Enable defacing volume',...
            'FontSize', 12,'backgroundColor','white','Value',enable_defacing,...
            'callback',@enable_Callback);
         
            function enable_Callback(src, ~) 
                enable_defacing = get(src,'Value');
            end
                 
        uicontrol('style','text','units','normalized','position',[0.05 0.55 0.4 0.2],'horizontalalignment','left',...
            'string','Bounding Box (MEG coordinates): ','fontsize',14,'backgroundColor','white','FontWeight','normal');           
       
        
        uicontrol('style','text','units','normalized','position',[0.05 0.4 0.2 0.2],'horizontalalignment','left',...
            'string','X Min (cm)','fontsize',12,'backgroundColor','white','FontWeight','normal');       
        xmin = uicontrol('style','edit','units','normalized','position',...
            [0.2 0.5 0.1 0.1],'String', num2str(deface_bb(1) * 0.1),...
            'FontSize', 12,'backgroundColor','white');

        uicontrol('style','text','units','normalized','position',[0.4 0.4 0.2 0.2],'horizontalalignment','left',...
            'string','X Max (cm)','fontsize',12,'backgroundColor','white','FontWeight','normal');       
        xmax = uicontrol('style','edit','units','normalized','position',...
            [0.55 0.5 0.1 0.1],'String', num2str(deface_bb(2) * 0.1),...
            'FontSize', 12,'backgroundColor','white');

        
        uicontrol('style','text','units','normalized','position',[0.05 0.25 0.2 0.2],'horizontalalignment','left',...
            'string','Y Min (cm)','fontsize',12,'backgroundColor','white','FontWeight','normal');       
        ymin = uicontrol('style','edit','units','normalized','position',...
            [0.2 0.35 0.1 0.1],'String', num2str(deface_bb(3) * 0.1),...
            'FontSize', 12,'backgroundColor','white');

        uicontrol('style','text','units','normalized','position',[0.4 0.25 0.2 0.2],'horizontalalignment','left',...
            'string','Y Max (cm)','fontsize',12,'backgroundColor','white','FontWeight','normal');       
        ymax = uicontrol('style','edit','units','normalized','position',...
            [0.55 0.35 0.1 0.1],'String', num2str(deface_bb(4) * 0.1),...
            'FontSize', 12,'backgroundColor','white');        
 
        uicontrol('style','text','units','normalized','position',[0.05 0.1 0.2 0.2],'horizontalalignment','left',...
            'string','Z Min (cm)','fontsize',12,'backgroundColor','white','FontWeight','normal');       
        zmin = uicontrol('style','edit','units','normalized','position',...
            [0.2 0.2 0.1 0.1],'String', num2str(deface_bb(5) * 0.1),...
            'FontSize', 12,'backgroundColor','white');

        uicontrol('style','text','units','normalized','position',[0.4 0.1 0.2 0.2],'horizontalalignment','left',...
            'string','Z Max (cm)','fontsize',12,'backgroundColor','white','FontWeight','normal');       
        zmax = uicontrol('style','edit','units','normalized','position',...
            [0.55 0.2 0.1 0.1],'String', num2str(deface_bb(6) * 0.1),...
            'FontSize', 12,'backgroundColor','white');        
        
        uicontrol('Units','Normalized','Position',[0.75 0.15 0.2 0.15],'String','Apply',...
            'FontSize',12,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@close_callback);
          
            function close_callback(~, ~) 
                deface_bb(1) = str2double(get(xmin,'string')) * 10.0;
                deface_bb(2) = str2double(get(xmax,'string')) * 10.0;
                deface_bb(3) = str2double(get(ymin,'string')) * 10.0;
                deface_bb(4) = str2double(get(ymax,'string')) * 10.0;
                deface_bb(5) = str2double(get(zmin,'string')) * 10.0;
                deface_bb(6) = str2double(get(zmax,'string')) * 10.0;


                uiresume(f2);        
                close(f2); 
            end
            
        uiwait(f2);
        
    end

    function loadFSMeshCallback(~,~)
             
        [meshfilename, meshfilepath, ~] = uigetfile({'rh.*;lh.*', 'FreeSurfer Surface (rh.*, lh.*)'},'Select a FreeSurfer Surface');
        meshFile = fullfile(meshfilepath, meshfilename);
        if isempty(meshfilename)
            return;
        end
        
        tstr=sprintf('Surface File:%s', meshFile);       
        set(WORKSPACE_TEXT_TITLE2,'string', tstr, 'enable','on');
        
        [~, mdata] = bw_readMeshFile(meshFile);
       
        % want meshes in voxel (MRI) relative coordinates
        
        % ** for freesurfer meshes we have to scale mesh back to RAS voxels (native) space
        % ** have to scale then translate origin which is center of image...

        fprintf('rescaling mesh from mm to voxels (scale = %g mm/voxel)\n', mmPerVoxel);
               
        mdata.vertices = mdata.vertices ./ mmPerVoxel;
        % translate origin to correspond to original RAS volume
        % adding 129 instead of 128 seems to make MNI coords line up on midline better
        % both on .nii and for Talairach coordinates. Also corresponds to
        % conversion shown in surfaceRAS to Talairach conversion documentation                   
        mdata.vertices = mdata.vertices + 129;
                
        if ~isempty(meshdata)
            resp = questdlg('Replace or add to current mesh?', 'Loading Freesurfer Surface','Replace','Add','Replace');
            switch resp
                case 'Add'
                    % increment face indices to start at end of previous vertex list
                    mdata.faces = mdata.faces + size(meshdata.vertices,1);   
                    meshdata.vertices = [meshdata.vertices; mdata.vertices];
                    meshdata.faces = [meshdata.faces; mdata.faces];
                case 'Replace'
                    meshdata.vertices = mdata.vertices;                    
                    meshdata.faces = mdata.faces;                    
            end          
        else
            meshdata.vertices = mdata.vertices;     
            meshdata.faces = mdata.faces;                    
        end
        clear mdata;
        

        displayMesh;
        set(CLR_SURFACE, 'enable', 'on');
            
    end

    function loadCIVETMeshCallback(~,~)
                     
        [meshfilename, meshfilepath, ~] = uigetfile({'*.obj', 'CIVET Surface (*.obj)'},'Select a CIVET Surface');
        meshFile = fullfile(meshfilepath, meshfilename);
        
        if isempty(meshFile)
            return;
        end
        
        tstr=sprintf('Surface File:%s', meshFile);       
        set(WORKSPACE_TEXT_TITLE2,'string', tstr, 'enable','on');
        
        [~, mdata] = bw_readMeshFile(meshFile);

        % ** CIVET mesh is in MNI coords. need to transform back to voxels
        % look for t1_tal.xfm file in default location
        tpath = meshfilepath(1:end-9); 
        transformPath = sprintf('%s%stransforms%slinear%s',tpath,filesep,filesep,filesep);
        % find file <prepend>_t1_tal.xfm 
        t = dir(fullfile(transformPath, '*tal.xfm'));
        transformFile = fullfile(transformPath, t.name);

        fprintf('looking for transformation file (%s)\n', transformFile);
        
        t = importdata(transformFile);
        transform = [t.data; 0 0 0 1];
        fprintf('transforming mesh from MNI to original NIfTI coordinates using transformation:\n');  
        mni_to_native = inv(transform)'

        t_vertices = [mdata.vertices, ones(size(mdata.vertices,1), 1) ];
        t_vertices = t_vertices * mni_to_native ; 
        t_vertices(:,4) = [];
        mdata.vertices = t_vertices;
       
        % scale mesh back to RAS voxels (native) space
        fprintf('rescaling mesh from mm to voxels (scale = %g mm/voxel)\n', mmPerVoxel);
        mdata.vertices = mdata.vertices ./mmPerVoxel;
               
        if ~isempty(meshdata)
            resp = questdlg('Replace or add to current surface?', 'Loading CIVET Surface','Replace','Add','Replace');
            switch resp
            case 'Add'
                % increment face indices to start at end of previous vertex list
                mdata.faces = mdata.faces + size(meshdata.vertices,1);   
                meshdata.vertices = [meshdata.vertices; mdata.vertices];
                meshdata.faces = [meshdata.faces; mdata.faces];
            case 'Replace'
                meshdata.vertices = mdata.vertices;                    
                meshdata.faces = mdata.faces;                    
            end          
        else
            meshdata.vertices = mdata.vertices;     
            meshdata.faces = mdata.faces;                    
        end
        clear mdata;
        
        displayMesh;
        set(CLR_SURFACE, 'enable', 'on');  
        
    end

    % puts mesh data into surface points structure and display
    % call each time mesh loaded or added to ...
    function displayMesh()

        if isempty(meshdata)
            return;
        end

        surface_faces = meshdata.faces;  % ignore 4th column
        surface_points = round(meshdata.vertices);

        surface_points_RPI = [];

        % flip from RAS to RPI and increment to 1 to 256
        % *** assumes input is 0 to 255 ***
        surface_points_RPI(:,1) = surface_points(:,1)+1;   
        surface_points_RPI(:,2) = slice_dim(2)-surface_points(:,2);
        surface_points_RPI(:,3) = slice_dim(3)-surface_points(:,3);

        % need to compute surface normals in MEG (i.e., display) coordinates
        
        fprintf('computing surface normals...\n');        
        surface_points_orien_RPI = bw_computeFaceNormals(double(surface_points_RPI'),double(surface_faces'));
        surface_points_orien_RPI =surface_points_orien_RPI';

        updateDisplay;
        
    end

    %%% this function needs to be re-tested ...
    
    function warp_templateCallback(~,~)
                
        if (template_val == 0)
            bw_warning_dialog('You must first load a template MRI file...');
            return;
        end
             
        % warp template to head shape points...
        fid1 = [na_RAS;le_RAS;re_RAS];

        % only use head shape points above LPA, RPA 
        thresh = (le_RAS(3)+re_RAS(3))/2;
        list = find(shape_points_RAS(:,3)> thresh);
        shape_points_RAS_c = shape_points_RAS(list,:);
        
        % get template scalp surface in mm
        template_shape_points = bw_getHeadShape(template_filename,na_RAS,le_RAS,re_RAS,mmPerVoxel);
        template_shape_points = template_shape_points*10;
             
        wbh = waitbar(0,'Warping template MRI to fit shape points using spm_eeg_inv_icp...');
        for i=10:5:20
            waitbar(i/100,wbh);
        end        
        
        % convert to RAS voxels
        M1 = bw_getAffineVox2CTF(na_RAS,le_RAS,re_RAS,1);   
        n = size(template_shape_points,1);
        template_shape_points_RAS = [template_shape_points ones(n,1)]*inv(M1);
        template_shape_points_RAS = template_shape_points_RAS(:,1:3);

        fid0 = [na_RAS;le_RAS;re_RAS];
        
        % take template scalpe surface above LPA, RPA
        thresh = (le_RAS(3)+re_RAS(3))/2;
        list = find(template_shape_points_RAS(:,3)> thresh);
        template_shape_points_RAS_c = template_shape_points_RAS(list,:);
       
        
        % Get the affine Matrix make template MRI shape fit the subject head shape
        %M = spm_eeg_inv_icp(double(template_shape_points_RAS'),double(shape_points_RAS'), [0 0 0]', [0 0 0]', [], [], 1);
        M = spm_eeg_inv_icp(double(template_shape_points_RAS_c'),double(shape_points_RAS_c'), fid0', fid1', [], [], 1);
        
        % create volume for new MRI
        img_RAS = zeros(slice_dim(1),slice_dim(2),slice_dim(3));

        y = max_dim - (0:(slice_dim(2)-1)) .* 1;
        x = 1 + (0:(slice_dim(1)-1)) .* 1; % X values
        xy = [reshape(repmat(y, max_dim, 1), 1, max_dim*max_dim); repmat(x, 1, max_dim)]; % tile and reshape XY values
        clear x y;
        z = 1 + (0:(max_dim-1)); % Z values
        
        HeadLoc = [repmat(xy, 1, max_dim); reshape(repmat(z, max_dim*max_dim, 1), 1, max_dim*max_dim*max_dim)];
        clear z;
        clear xy;
                 
        % rotate and scale to voxels using the warping affine
        % transformation defined by M from Head shape points to template MRI
        % voxels
        fprintf('Converting into MR space ...\n');
        tic 
        temp = HeadLoc(1,:);        
        HeadLoc(1,:) =  HeadLoc(2,:);
        HeadLoc(2,:) = max_dim+1- temp;        
        clear temp;
        
        MriLoc = M* [HeadLoc; ones(1, max_dim*max_dim*max_dim)];
        
        MriVox = MriLoc(1:3, :);
        clear MriLoc;
        toc
        
        % create final image - use mex version of interp3 if possible.
        % interpolates values in the template MRI volume (mri_nii.img) onto
        % warped volume (which is then saved as regular grid) ...
        fprintf('Interpolating image ...\n');
        tic
        if (exist('trilinear') == 3)
            img_RAS = trilinear(double(mri_nii.img), double(reshape(MriVox(2, :), max_dim, max_dim, max_dim)), double(reshape(MriVox(1, :), max_dim, max_dim, max_dim)), double(reshape(MriVox(3, :), max_dim, max_dim, max_dim)));
        else
            img_RAS = interp3(double(mri_nii.img), reshape(MriVox(2, :), max_dim, max_dim, max_dim), reshape(MriVox(1, :), max_dim, max_dim, max_dim), reshape(MriVox(3, :), max_dim, max_dim, max_dim), 'linear',0);
        end
        
        for i=20:5:100
            waitbar(i/100,wbh,'done....');
        end
        delete(wbh);
        
        img2 = flipdim(img_RAS,3);
        % flip y direction RAI -> RPI
        img = flipdim(img2,2);
        img_display1 = img;
        img_display1=uint8(img_display1);
        clear img2;

        sag_view(size(img_display,1)/2,size(img_display,2)/2,size(img_display,3)/2);
        cor_view(size(img_display,1)/2,size(img_display,2)/2,size(img_display,3)/2);
        axi_view(size(img_display,1)/2,size(img_display,2)/2,size(img_display,3)/2);

        % Save isotropic nii file
        
        fid =[na_RAS;le_RAS;re_RAS];        
       
        fid = inv(M)*[fid';1 1 1];
        fid = fid(1:3,:)';
        
        na_RAS = round(fid(1,:));
        le_RAS = round(fid(2,:));
        re_RAS = round(fid(3,:));
        
        [filename, pathname, ~] = uiputfile( ...
            {'*','MRI_DIRECTORY'; '*.mri','CTF MRI file (*.mri)'}, ...
            'Enter Subject ID for MRI Directory');

        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        filename_full = fullfile(pathname, filename);
        
        save_MRI_dir(filename_full);
                      
    end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% image display functions and callbacks for mri/nii files(RPI&RAS)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function cor_view(s,c,a)
        coraxis=subplot(2,2,1);
        
        % coordinates in RPI for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
                
        mdata = rot90(fliplr(squeeze(img_display1(:,c,:))));
        mdata = mdata * contrast_value;

        idx = find(mdata > 127);
        mdata(idx) = 127;        
        
        if ~isempty(overlay.image) 
            
            % render CTF image onto this plane
            thisSlice = slice2_RAS;

            if strcmp(overlay.imageType,'CTF')
                M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel );    
            else
                transforms = getMNITransforms;
                M = transforms.RAS_to_MNI;  
            end

            %NEW
            % 1) vox -> ctf coordinates of current plane
            [X, Y, Z] = meshgrid(1:slice_dim(1), thisSlice, 1:slice_dim(3));
            points = [X(:), Y(:), Z(:)];

            % convert voxel grid to MNI coordinates 
            ctf_points = [points, ones(size(points,1),1)]* M;
            ctf_points(:, 4) = [];
            y_plane = ctf_points;
            
            % 2) get mask for coordinates that exceed bounded box 
            mask = ctf_points(:,1) > overlay.bb(1) & ctf_points(:,1) < overlay.bb(2) & ...
                ctf_points(:,2) > overlay.bb(3) & ctf_points(:,2) < overlay.bb(4) & ...
                ctf_points(:,3) > overlay.bb(5) & ctf_points(:,3) < overlay.bb(6);
            mask = [mask, mask, mask];

            % 3) get coordinates in bounded box coordinate space (minus
            % bounded box offsets and in overlay resolution)
            bb1(1:size(y_plane(:,1),1)) = overlay.bb(1);
            bb2(1:size(y_plane(:,2),1)) = overlay.bb(3);
            bb3(1:size(y_plane(:,3),1)) = overlay.bb(5);
            y_plane(:,1) = round((y_plane(:,1) - bb1')/overlay.RES(1))+1;
            y_plane(:,2) = round((y_plane(:,2) - bb2')/overlay.RES(2))+1;
            y_plane(:,3) = round((y_plane(:,3) - bb3')/overlay.RES(3))+1;
            
            % set any coordinates exceeding bounded box to 1,1,1 -- CHANGE?
            y_plane = y_plane.*mask; 
            y_plane(y_plane==0) = 1;
            
            % 
            Is = size(overlay.image);
            Ioff = cumprod([1 Is(1:end-1)]);
            yidx = (y_plane-1) * Ioff.' + 1;

            % get indices into display image (blank image)
            vox_img = zeros(max_dim,max_dim);
            [x, y] = meshgrid(1:max_dim, 1:max_dim);
            vox_points = [x(:), y(:)];
            Is2 = size(vox_img);
            Ioff2 = cumprod([1 Is2(1:end-1)]);
            yidx2 = (vox_points-1) * Ioff2.' + 1;

            % render overlay onto display image
%             vox_img(yidx2) = (overlay.image(yidx)/overlay.max)*127.0+128;
            vox_img(yidx2) = (overlay.image(yidx)/overlay.max)*64.0+(128+64);
    
            vox_img = flipdim(vox_img,1);
 
            colormap(cmap);
            imagesc(mdata,[0 255]);
             
            hold on;

            % influence transparency (allow background image to show
            % through where overlay data low)
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;
            set(im, 'AlphaData', mask);
           
            hold off;
        else            
            imagesc(mdata,[0 127]);
            colormap(gmap);
        end

        % mask image is binary image matching MRI volume
        if ~isempty(maskOverlay.image) 

            colormap(cmap);
            imagesc(mdata,[0 255]);

            hold on;

            % influence transparency (allow background image to show
            % through where overlay data low)
            vox_img = rot90(fliplr(squeeze(maskOverlay.image(:,c,:))));
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;
            set(im, 'AlphaData', mask);
           
            hold off;            
        end

        % create a circle
        trad = (1/16:1/8:1)'*2*pi;
        xadd = pt_size*sin(trad);
        yadd = pt_size*cos(trad);
        
        if ~isempty(shape_points_RPI)
            x = [];
            y = [];
            hold on;
            if showAllPoints
                idx = 1:size(shape_points_RPI,1);
            else
                idx = find(shape_points_RPI(:,2)==c);
            end

            if ~isempty(idx)
                % draw filled dots as patches
                xpts = shape_points_RPI(idx,1);
                ypts = shape_points_RPI(idx,3);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'green');
            end
            hold off;
        end
        
        if ~isempty(sensor_points)
            hold on;
            x = [];
            y = [];
            xpts = sensor_points_RPI(:,1);
            ypts = sensor_points_RPI(:,3);
            for i=1:length(xpts)            
                x(:,i) = xpts(i) + xadd;
                y(:,i) = ypts(i) + yadd;               
            end
            patch(x,y,'yellow');
            hold off;
        end
        
        if ~isempty(surface_points)
            hold on;
            x = [];
            y = [];
            idx = find(surface_points_RPI(:,2)==c);   
            if ~isempty(idx)
                % draw filled dots as patches
                xpts = surface_points_RPI(idx,1);
                ypts = surface_points_RPI(idx,3);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'red');
                if tail_show && ~isempty(surface_points_orien_RPI)
                    % draw tails
                    xori = surface_points_orien_RPI(idx,1);
                    yori = surface_points_orien_RPI(idx,3);
                    quiver(xpts,ypts, xori, yori,tail_len,'color','y','linewidth',(tail_len / 4));
                end
            end
            hold off;
            
        end          
        
        if ~isempty(sphereList)
            hold on;            
            % plot mean sphere (is same as single sphere)
            origins = sphereList(:,1:3) * 10.0;  % sphere origin in voxels
            [origin_vox,~] = Head_to_Voxels(origins);
            if isSingleSphere  
                spheresToPlot = 1;
            else
                spheresToPlot = size(sphereList,1);
            end
            for i=1:spheresToPlot
                origin = origin_vox(i,1:3);
                radius_vox = sphereList(i,4) * 10.0 / mmPerVoxel; % radius in voxels
                if(abs(c-origin(2)) < radius_vox)
                    circle_radius = sqrt(radius_vox^2-(c-origin(2))^2);
                    circle_origin = [origin(1) origin(3)];
                    circle(circle_origin,circle_radius,1000,'b-');
                    plot(circle_origin(1),circle_origin(2),'g+');
                end
            end
            hold off;
        end
        
        if ~isempty(dip_params_RPI)
            hold on;
            if showAllDipoles
                idx = 1:size(dip_params_RPI,1);
            else
                idx = find(dip_params_RPI(:,2)==c);
            end

            if ~isempty(idx)
                % draw filled dots as patches
                xpts = dip_params_RPI(idx,1);
                ypts = dip_params_RPI(idx,3);
                xori = dip_orient_RPI(idx,1);
                yori = dip_orient_RPI(idx,3);
                
                for i=1:length(xpts)            
                    x = xpts(i) + xadd*2;
                    y = ypts(i) + yadd*2;                        
                    col = dipColors{idx(i)};
                    patch(x,y,col);  
                end  

                % draw tails
                if (tail_show)
                    for i=1:length(xpts)
                        xp = [xpts(i) xpts(i)+xori(i)*10*pt_size];
                        yp = [ypts(i) ypts(i)+yori(i)*10*pt_size];
                        line(xp,yp,'color','y','linewidth',pt_size);
                    end             
                end
            end
            hold off;          
        end  
              
        image_size = size(mdata);
        
        axis off;
        
        % redraw cursors
        cor_hor=line([1,image_size(1)],[a,a],'color',cursor_color);
        cor_ver=line([s, s],[1,image_size(1)],'color',cursor_color);
        
        % draw fiducials
        na_RPI = [na_RAS(1)+1 slice_dim(2)-na_RAS(2) slice_dim(3)-na_RAS(3)];
        le_RPI = [le_RAS(1)+1 slice_dim(2)-le_RAS(2) slice_dim(3)-le_RAS(3)];
        re_RPI = [re_RAS(1)+1 slice_dim(2)-re_RAS(2) slice_dim(3)-re_RAS(3)];
        fids = [na_RPI; le_RPI; re_RPI];
        idx = find(fids(:,2)==c);
        if ~isempty(idx)
            hold on;            
            x = [];
            y = [];
            for i=1:length(idx)            
                x = fid_size*sin(trad)+fids(idx(i),1);
                y = fid_size*cos(trad)+fids(idx(i),3);
                fill(x,y,orange)                    
            end  
            hold off;        
        end
        
        updateCursorText;
       
    end

    function sag_view(s,c,a)
        sagaxis=subplot(2,2,2);

        % coordinates in RPI for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        mdata = rot90(fliplr(squeeze(img_display1(s,:,:))));
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127;        
        
        if ~isempty(overlay.image) 
          
            % render CTF image onto this plane
            thisSlice = slice1_RAS;

            if strcmp(overlay.imageType,'CTF')
                M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel );    
            else
                transforms = getMNITransforms;
                M = transforms.RAS_to_MNI;  
            end
            %NEW
              
            % 1) vox -> ctf coordinates of current plane
            [X, Y, Z] = meshgrid(thisSlice, 1:slice_dim(2), 1:slice_dim(3));
            points = [X(:), Y(:), Z(:)];
            ctf_points = [points, ones(size(points,1),1)]* M;
            ctf_points(:, 4) = [];
            
            % 2) mask for coordinates that exceed bounded box
            mask = ctf_points(:,1) > overlay.bb(1) & ctf_points(:,1) < overlay.bb(2) & ...
                ctf_points(:,2) > overlay.bb(3) & ctf_points(:,2) < overlay.bb(4) & ...
                ctf_points(:,3) > overlay.bb(5) & ctf_points(:,3) < overlay.bb(6);
            mask = [mask, mask, mask];
            x_plane = ctf_points;
            
            % 3)  get coordinates in bounded box coordinate space (minus
            % bounded box offsets and in overlay resolution)
            bb1(1:size(x_plane(:,1),1)) = overlay.bb(1);
            bb2(1:size(x_plane(:,2),1)) = overlay.bb(3);
            bb3(1:size(x_plane(:,3),1)) = overlay.bb(5);
            x_plane(:,1) = round((x_plane(:,1) - bb1')/overlay.RES(1))+1;
            x_plane(:,2) = round((x_plane(:,2) - bb2')/overlay.RES(2))+1;
            x_plane(:,3) = round((x_plane(:,3) - bb3')/overlay.RES(3))+1;
            
            % set coordinates exceeding bounded box to 1,1,1 -- CHANGE?
            x_plane = x_plane.*mask; 
            x_plane(x_plane==0) = 1;
            
            % convert coordinates into indices for overlay image
            Is = size(overlay.image);
            Ioff = cumprod([1 Is(1:end-1)]);
            xidx = (x_plane-1) * Ioff.' + 1;

            % get indices into display image (blank image)
            vox_img = zeros(max_dim,max_dim);
            [x, y] = meshgrid(1:max_dim, 1:max_dim);
            vox_points = [x(:), y(:)];
            Is2 = size(vox_img);
            Ioff2 = cumprod([1 Is2(1:end-1)]);
            xidx2 = (vox_points-1) * Ioff2.' + 1;

            % render overlay onto display image
%             vox_img(xidx2) = (overlay.image(xidx)/overlay.max)*127.0+128;
            vox_img(xidx2) = (overlay.image(xidx)/overlay.max)*64.0+(128+64);
            i = flipdim(vox_img,1);
            vox_img = flipdim(i,2);
            
            imagesc(mdata,[0 255]);
            colormap(cmap);
            
            hold on;

            % influence transparency (allow background image to show
            % through when overlay data low)
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;

            set(im, 'AlphaData', mask);
            hold off;
            
        else            
            imagesc(mdata,[0 127]);
            colormap(gmap);
        end

        % mask image is binary image matching MRI volume
        if ~isempty(maskOverlay.image) 

            colormap(cmap);
            imagesc(mdata,[0 255]);

            hold on;

            % influence transparency (allow background image to show
            % through where overlay data low)
            vox_img = rot90(fliplr(squeeze(maskOverlay.image(s,:,:))));
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;
            set(im, 'AlphaData', mask);
           
            hold off;            
        end


        trad = (1/16:1/8:1)'*2*pi;
        xadd = pt_size*sin(trad);
        yadd = pt_size*cos(trad);

        if ~isempty(shape_points_RPI)
            hold on;
            x = [];
            y = [];
            if showAllPoints
                idx = 1:size(shape_points_RPI,1);
            else
                idx = find(shape_points_RPI(:,1)==s);
            end            
            if ~isempty(idx)
                xpts = shape_points_RPI(idx,2);
                ypts = shape_points_RPI(idx,3);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'green');
            end
            
            hold off;
        end
        
        if ~isempty(sensor_points)
            hold on;
            x = [];
            y = [];
            xpts = sensor_points_RPI(:,2);
            ypts = sensor_points_RPI(:,3);
            for i=1:length(xpts)            
                x(:,i) = xpts(i) + xadd;
                y(:,i) = ypts(i) + yadd;               
            end
            patch(x,y,'yellow');
            hold off;
        end
        
        if ~isempty(surface_points)
            hold on;            
            x = [];
            y = [];
            idx = find(surface_points_RPI(:,1)==s);            
            if ~isempty(idx)
                xpts = surface_points_RPI(idx,2);
                ypts = surface_points_RPI(idx,3);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'red');
                if tail_show && ~isempty(surface_points_orien_RPI)
                    % draw tails
                    xori = surface_points_orien_RPI(idx,2);
                    yori = surface_points_orien_RPI(idx,3);
                    quiver(xpts,ypts, xori, yori,tail_len,'color','y','linewidth',(tail_len / 4));
                end
            end
            hold off;
        end
        
        if ~isempty(sphereList)
            hold on;            
            % plot mean sphere (is same as single sphere)
            origins = sphereList(:,1:3) * 10.0;  % sphere origin in voxels
            [origin_vox, ~] = Head_to_Voxels(origins);
            if isSingleSphere  
                spheresToPlot = 1;
            else
                spheresToPlot = size(sphereList,1);
            end
            for i=1:spheresToPlot
                origin = origin_vox(i,1:3);
                radius_vox = sphereList(i,4) * 10.0 / mmPerVoxel; % radius in voxels
                if(abs(s-origin(1))<radius_vox)
                    circle_radius=sqrt(radius_vox^2-(s-origin(1))^2);
                    circle_origin = [origin(2) origin(3)];
                    circle(circle_origin,circle_radius,1000,'b-');
                    plot(circle_origin(1),circle_origin(2),'g+');
                end
            end
            hold off;
        end
     
        if ~isempty(dip_params_RPI)
            hold on;
            if showAllDipoles
                idx = 1:size(dip_params_RPI,1);
            else
                idx = find(dip_params_RPI(:,1)==s);
            end
            if ~isempty(idx)
                % draw filled dots as patches
                xpts = dip_params_RPI(idx,2);
                ypts = dip_params_RPI(idx,3);
                xori = dip_orient_RPI(idx,2);
                yori = dip_orient_RPI(idx,3);
                for i=1:length(xpts)            
                    x = xpts(i) + xadd*2;
                    y = ypts(i) + yadd*2;               
                    col = dipColors{idx(i)};
                    patch(x,y,col);  
                end  
                % draw tails
                               
                if (tail_show)
                    for i=1:length(xpts)
                        xp = [xpts(i) xpts(i)+xori(i)*10*pt_size];
                        yp = [ypts(i) ypts(i)+yori(i)*10*pt_size];
                        line(xp,yp,'color','y','linewidth',pt_size);
                    end
                end
            end
            hold off;          
        end  
        
        image_size = size(mdata);
        
        axis off;
        sag_hor=line([1, image_size(1)],[a, a],'color',cursor_color);
        sag_ver=line([c, c],[1, image_size(2)],'color',cursor_color);
        
%         draw fiducials
        na_RPI = [na_RAS(1)+1 slice_dim(2)-na_RAS(2) slice_dim(3)-na_RAS(3)];
        le_RPI = [le_RAS(1)+1 slice_dim(2)-le_RAS(2) slice_dim(3)-le_RAS(3)];
        re_RPI = [re_RAS(1)+1 slice_dim(2)-re_RAS(2) slice_dim(3)-re_RAS(3)];
        fids = [na_RPI; le_RPI; re_RPI];
        idx = find(fids(:,1)==s);
        x = [];
        y = [];
        if ~isempty(idx)
            hold on;            
            t = (1/16:1/8:1)'*2*pi;
            for i=1:length(idx)            
                x = fid_size*sin(t)+fids(idx(i),2);
                y = fid_size*cos(t)+fids(idx(i),3);
                fill(x,y,orange)                    
            end  
            hold off;        
        end
        
        updateCursorText;
        
    end

    function axi_view(s,c,a)     
        axiaxis=subplot(2,2,3);

        % coordinates in RPI for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        mdata = rot90(fliplr(squeeze(img_display1(:,:,a))));          
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127;        
        
        if ~isempty(overlay.image) 

            % render CTF image onto this plane
            thisSlice = slice3_RAS;
            if strcmp(overlay.imageType,'CTF')
                M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel );    
            else
                transforms = getMNITransforms;
                M = transforms.RAS_to_MNI;  
            end

             %NEW
              
            % 1) vox -> ctf coordinates of current plane
            [X, Y, Z] = meshgrid(1:slice_dim(1), 1:slice_dim(2), thisSlice);
            points = [X(:), Y(:), Z(:)];
            ctf_points = [points, ones(size(points,1),1)]* M;
            ctf_points(:, 4) = [];
            
            % 2) mask for coordinates that exceed bounded box 
            mask = ctf_points(:,1) > overlay.bb(1) & ctf_points(:,1) < overlay.bb(2) & ...
                ctf_points(:,2) > overlay.bb(3) & ctf_points(:,2) < overlay.bb(4) & ...
                ctf_points(:,3) > overlay.bb(5) & ctf_points(:,3) < overlay.bb(6);
            mask = [mask, mask, mask];
            z_plane = ctf_points;
            
            % 3) get coordinates in bounded box coordinate space (minus
            % bounded box offsets and in overlay resolution)
            bb1(1:size(z_plane(:,1),1)) = overlay.bb(1);
            bb2(1:size(z_plane(:,2),1)) = overlay.bb(3);
            bb3(1:size(z_plane(:,3),1)) = overlay.bb(5);
            z_plane(:,1) = round((z_plane(:,1) - bb1')/overlay.RES(1))+1;
            z_plane(:,2) = round((z_plane(:,2) - bb2')/overlay.RES(2))+1;
            z_plane(:,3) = round((z_plane(:,3) - bb3')/overlay.RES(3))+1;
            
            % set coordinates exceeding bounded box to 1,1,1 -- CHANGE to set to NAN?
            z_plane = z_plane.*mask; 
            z_plane(z_plane==0) = 1;
            
            % convert coordinates into indices for overlay image
            Is = size(overlay.image);
            Ioff = cumprod([1 Is(1:end-1)]);
            zidx = (z_plane-1) * Ioff.' + 1;
            
            % get indices into display image (blank image)
            vox_img = zeros(max_dim, max_dim);
            [x, y] = meshgrid(1:max_dim, 1:max_dim);
            vox_points = [x(:), y(:)];
            Is2 = size(vox_img);
            Ioff2 = cumprod([1 Is2(1:end-1)]);
            zidx2 = (vox_points-1) * Ioff2.' + 1;

            % render overlay onto display image
%             vox_img(zidx2) = (overlay.image(zidx)/overlay.max)*127.0+128;
            vox_img(zidx2) = (overlay.image(zidx)/overlay.max)*64.0+(128+64);
  
            i = flipdim(vox_img,2);
            vox_img = rot90(fliplr(squeeze(i)));
            
            imagesc(mdata,[0 255]);
            colormap(cmap);
             
            hold on;

            % influence transparency (allow background image to show
            % through when overlay data low)
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;

            set(im, 'AlphaData', mask);
            hold off;
        else       
            imagesc(mdata,[0 127]);
            colormap(gmap);
        end

        % mask image is binary image matching MRI volume
        if ~isempty(maskOverlay.image) 

            colormap(cmap);
            imagesc(mdata,[0 255]);

            hold on;

            % influence transparency (allow background image to show
            % through where overlay data low)
            vox_img = rot90(fliplr(squeeze(maskOverlay.image(:,:,a))));          
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;
            set(im, 'AlphaData', mask);
           
            hold off;            
        end

        trad = (1/16:1/8:1)'*2*pi;
        xadd = pt_size*sin(trad);
        yadd = pt_size*cos(trad); 
        
        if ~isempty(shape_points_RPI)
            hold on;
            x = [];
            y = [];
            if showAllPoints
                idx = 1:size(shape_points_RPI,1);
            else
                idx = find(shape_points_RPI(:,3)==a);
            end
            if ~isempty(idx)
                xpts = shape_points_RPI(idx,1);
                ypts = shape_points_RPI(idx,2);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'green');
            end
            hold off;
        end
        
        if ~isempty(sensor_points)
            hold on;
            x = [];
            y = [];
            xpts = sensor_points_RPI(:,1);
            ypts = sensor_points_RPI(:,2);
            for i=1:length(xpts)            
                x(:,i) = xpts(i) + xadd;
                y(:,i) = ypts(i) + yadd;               
            end
            patch(x,y,'yellow');
            hold off;
        end

        if ~isempty(surface_points)
            hold on;             
            idx = find(surface_points_RPI(:,3)==a);
            if ~isempty(idx)
                x = [];
                y = [];
                xpts = surface_points_RPI(idx,1);
                ypts = surface_points_RPI(idx,2);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'red');
                if tail_show && ~isempty(surface_points_orien_RPI)
                    % draw tails
                    xori = surface_points_orien_RPI(idx,1);
                    yori = surface_points_orien_RPI(idx,2);
                    quiver(xpts,ypts, xori, yori,tail_len,'color','y','linewidth',(tail_len / 4));
                end
            end
            hold off;            
        end
        
        if ~isempty(sphereList)
            hold on;            
            % plot mean sphere (is same as single sphere)
            origins = sphereList(:,1:3) * 10.0;  % sphere origin in voxels
            [origin_vox, ~] = Head_to_Voxels(origins);
            if isSingleSphere  
                spheresToPlot = 1;
            else
                spheresToPlot = size(sphereList,1);
            end
            for i=1:spheresToPlot
                origin = origin_vox(i,1:3);
                radius_vox = sphereList(i,4) * 10.0 / mmPerVoxel; % radius in voxels
                if(abs(a-origin(3))<radius_vox)
                    circle_radius = sqrt(radius_vox^2-(a-origin(3))^2);
                    circle_origin = [origin(1) origin(2)];
                    circle(circle_origin,circle_radius,1000,'b-');
                    plot(circle_origin(1),circle_origin(2),'g+');
                end
            end
            hold off;
        end    
 
        if ~isempty(dip_params_RPI)
            hold on;
            if showAllDipoles
                idx = 1:size(dip_params_RPI,1);
            else
                idx = find(dip_params_RPI(:,3)==a);   
            end
            if ~isempty(idx)
                % draw filled dots as patches
                xpts = dip_params_RPI(idx,1);
                ypts = dip_params_RPI(idx,2);
                xori = dip_orient_RPI(idx,1);
                yori = dip_orient_RPI(idx,2);
                for i=1:length(xpts)            
                    x = xpts(i) + xadd*2;
                    y = ypts(i) + yadd*2;               
                    col = dipColors{idx(i)};
                    patch(x,y,col);
                end  

                % draw tails                           
                if (tail_show)
                    for i=1:length(xpts)
                        xp = [xpts(i) xpts(i)+xori(i)*10*pt_size];
                        yp = [ypts(i) ypts(i)+yori(i)*10*pt_size];
                        line(xp,yp,'color','y','linewidth',pt_size);
                    end               
                end
            end
            hold off;          
        end  
        
        image_size = size(mdata);
        
        axis off;
        axi_hor=line([1, image_size(1)],[c, c],'color',cursor_color);
        axi_ver=line([s, s],[1, image_size(2)],'color',cursor_color);
        
        % draw fiducials
        na_RPI = [na_RAS(1)+1 slice_dim(2)-na_RAS(2) slice_dim(3)-na_RAS(3)];
        le_RPI = [le_RAS(1)+1 slice_dim(2)-le_RAS(2) slice_dim(3)-le_RAS(3)];
        re_RPI = [re_RAS(1)+1 slice_dim(2)-re_RAS(2) slice_dim(3)-re_RAS(3)];
        fids = [na_RPI; le_RPI; re_RPI];
        idx = find(fids(:,3)==a);
        if ~isempty(idx)
            x = [];
            y = [];
            hold on;            
            t = (1/16:1/8:1)'*2*pi;
            for i=1:length(idx)           
                x = fid_size*sin(t)+fids(idx(i),1);
                y = fid_size*cos(t)+fids(idx(i),2);
                fill(x,y,orange)                    
            end  
            hold off;        
        end
        updateCursorText;
        
    end

    % update position of crosshairs when update slice viewing
    function updateCrosshairs(s,c,a)
        
        % coordinates in RPI for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        % cor view
        coraxis=subplot(2,2,1);
        delete(cor_hor);
        delete(cor_ver);
        axis off;
        cor_hor=line([1, image_size(1)],[a, a],'color',cursor_color);
        cor_ver=line([s, s],[1, image_size(2)],'color',cursor_color);
        
        % sag view
        sagaxis=subplot(2,2,2);
        delete(sag_hor);
        delete(sag_ver);
        axis off;
        sag_hor=line([1, image_size(1)],[a, a],'color',cursor_color);
        sag_ver=line([c, c],[1,image_size(2)],'color',cursor_color);
        
        % axi view
        axiaxis=subplot(2,2,3);
        delete(axi_hor);
        delete(axi_ver);
        axis off;
        axi_hor=line([1,image_size(1)],[c, c],'color',cursor_color);
        axi_ver=line([s, s],[1, image_size(2)],'color',cursor_color);
           
    end

    function cor_view_big(s,c,a)
        
        % coordinates in RPI for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        mdata = rot90(fliplr(squeeze(img_display1(:,c,:))));
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127;        
        
        if ~isempty(overlay.image) 
          
            % render CTF image onto this plane
            if strcmp(overlay.imageType,'CTF')
                M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel );    
            else
                transforms = getMNITransforms;
                M = transforms.RAS_to_MNI;  
            end

            thisSlice = slice2_big_RAS;
            
            % 1) vox -> ctf coordinates of current plane
            [X, Y, Z] = meshgrid(1:slice_dim(1), thisSlice, 1:slice_dim(3));
            points = [X(:), Y(:), Z(:)];
            ctf_points = [points, ones(size(points,1),1)]* M;
            ctf_points(:, 4) = [];
            
            % 2) mask for coordinates that exceed bounded box 
            mask = ctf_points(:,1) > overlay.bb(1) & ctf_points(:,1) < overlay.bb(2) & ...
                ctf_points(:,2) > overlay.bb(3) & ctf_points(:,2) < overlay.bb(4) & ...
                ctf_points(:,3) > overlay.bb(5) & ctf_points(:,3) < overlay.bb(6);
            mask = [mask, mask, mask];
            y_plane = ctf_points;
            
            % 3) get coordinates in bounded box coordinate space (minus
            % bounded box offsets and in overlay resolution)
            bb1(1:size(y_plane(:,1),1)) = overlay.bb(1);
            bb2(1:size(y_plane(:,2),1)) = overlay.bb(3);
            bb3(1:size(y_plane(:,3),1)) = overlay.bb(5);
            y_plane(:,1) = round((y_plane(:,1) - bb1')/overlay.RES(1))+1;
            y_plane(:,2) = round((y_plane(:,2) - bb2')/overlay.RES(2))+1;
            y_plane(:,3) = round((y_plane(:,3) - bb3')/overlay.RES(3))+1;
            
            % set coordinates exceeding bounded box to 1,1,1 -- CHANGE?
            y_plane = y_plane.*mask; 
            y_plane(y_plane==0) = 1;
            
            % convert coordinates into indices for overlay image
            Is = size(overlay.image);
            Ioff = cumprod([1 Is(1:end-1)]);
            yidx = (y_plane-1) * Ioff.' + 1;
            
            % get indices into display image (blank image)
            vox_img = zeros(max_dim, max_dim);
            
            [x, y] = meshgrid(1:max_dim, 1:max_dim);
            vox_points = [x(:), y(:)];
            Is2 = size(vox_img);
            Ioff2 = cumprod([1 Is2(1:end-1)]);
            yidx2 = (vox_points-1) * Ioff2.' + 1;
            
            % render overlay onto display image
%             vox_img(yidx2) = (overlay.image(yidx)/overlay.max)*127.0+128;
            vox_img(yidx2) = (overlay.image(yidx)/overlay.max)*64.0+(128+64);
            vox_img = flipdim(vox_img,1);

            imagesc(mdata,[0 255]);
            colormap(cmap); 
            
            hold on;

            % influence transparency (allow background image to show
            % through when overlay data low)
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;

            set(im, 'AlphaData', mask);
            hold off;
            
        else            
            imagesc(mdata,[0 127]);
            colormap(gmap);       
        end

        if ~isempty(maskOverlay.image) 

            colormap(cmap);
            imagesc(mdata,[0 255]);

            hold on;

            % influence transparency (allow background image to show
            % through where overlay data low)
            vox_img = rot90(fliplr(squeeze(maskOverlay.image(:,c,:))));
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;
            set(im, 'AlphaData', mask);
           
            hold off;            
        end

        trad = (1/16:1/8:1)'*2*pi;
        xadd = pt_size*sin(trad);
        yadd = pt_size*cos(trad);
        
        if ~isempty(shape_points_RPI)
            hold on;
            x = [];
            y = [];
            if showAllPoints
                idx = 1:size(shape_points_RPI,1);
            else
                idx = find(shape_points_RPI(:,2)==c);
            end
            if ~isempty(idx)
                xpts = shape_points_RPI(idx,1);
                ypts = shape_points_RPI(idx,3);
                xadd = pt_size*sin(trad);
                yadd = pt_size*cos(trad);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'green');  
            end
            hold off;
        end
        if ~isempty(sensor_points)
            hold on;
            x = [];
            y = [];
            xpts = sensor_points_RPI(:,1);
            ypts = sensor_points_RPI(:,3);
            for i=1:length(xpts)            
                x(:,i) = xpts(i) + xadd;
                y(:,i) = ypts(i) + yadd;               
            end
            patch(x,y,'yellow');           
            hold off;
        end
        
        if ~isempty(surface_points)
            hold on;
            x = [];
            y = [];
            idx = find(surface_points_RPI(:,2)==c);          
            trad = (1/16:1/8:1)'*2*pi;
            if ~isempty(idx)
                xpts = surface_points_RPI(idx,1);
                ypts = surface_points_RPI(idx,3);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'red');      
                if tail_show && ~isempty(surface_points_orien_RPI)
                    % draw tails
                    xori = surface_points_orien_RPI(idx,1);
                    yori = surface_points_orien_RPI(idx,3);
                    quiver(xpts,ypts, xori, yori,tail_len,'color','y','linewidth',(tail_width));
                end  
            end
            hold off;         
        end
        
        if ~isempty(sphereList)
            hold on;            
            % plot mean sphere (is same as single sphere)
            origins = sphereList(:,1:3) * 10.0;  % sphere origin in voxels
            [origin_vox,~] = Head_to_Voxels(origins);
            if isSingleSphere  
                spheresToPlot = 1;
            else
                spheresToPlot = size(sphereList,1);
            end
            for i=1:spheresToPlot
                origin = origin_vox(i,1:3);
                radius_vox = sphereList(i,4) * 10.0 / mmPerVoxel; % radius in voxels
                if(abs(c-origin(2)) < radius_vox)
                    circle_radius = sqrt(radius_vox^2-(c-origin(2))^2);
                    circle_origin = [origin(1) origin(3)];
                    circle(circle_origin,circle_radius,1000,'b-');
                    plot(circle_origin(1),circle_origin(2),'g+');
                end
            end
            hold off;
        end
        
        if ~isempty(dip_params_RPI)
            hold on;
            if showAllDipoles
                idx = 1:size(dip_params_RPI,1);
            else
                idx = find(dip_params_RPI(:,2)==c);
            end
                
            if ~isempty(idx)
                % draw filled dots as patches
                xpts = dip_params_RPI(idx,1);
                ypts = dip_params_RPI(idx,3);
                xori = dip_orient_RPI(idx,1);
                yori = dip_orient_RPI(idx,3);
                for i=1:length(xpts)            
                    x = xpts(i) + xadd*2;
                    y = ypts(i) + yadd*2;               
                    col = dipColors{idx(i)};
                    patch(x,y,col);
                end  
                % draw tails
                for i=1:length(xpts)
                    xp = [xpts(i) xpts(i)+xori(i)*10*pt_size];
                    yp = [ypts(i) ypts(i)+yori(i)*10*pt_size];
                    line(xp,yp,'color','y','linewidth',pt_size*2);
                end               
            end
            hold off;          
        end  
        
        image_size = size(mdata);
        
        axis off;
        cor_hor_big = line([1, image_size(1)],[a, a],'color',cursor_color);
        cor_ver_big = line([s, s],[1 image_size(2)],'color',cursor_color);
        
        % draw fiducials
        na_RPI = [na_RAS(1)+1 slice_dim(2)-na_RAS(2) slice_dim(3)-na_RAS(3)];
        le_RPI = [le_RAS(1)+1 slice_dim(2)-le_RAS(2) slice_dim(3)-le_RAS(3)];
        re_RPI = [re_RAS(1)+1 slice_dim(2)-re_RAS(2) slice_dim(3)-re_RAS(3)];
        fids = [na_RPI; le_RPI; re_RPI];
        idx = find(fids(:,2)==c);
        if ~isempty(idx)
            x = [];
            y = [];
            hold on;            
            t = (1/16:1/8:1)'*2*pi;
            for i=1:length(idx)            
                x = fid_size*sin(t)+fids(idx(i),1);
                y = fid_size*cos(t)+fids(idx(i),3);
                fill(x,y,orange)                    
            end  
            hold off;        
        end
    end

    function sag_view_big(s,c,a)

        % coordinates in RPI for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        mdata = rot90(fliplr(squeeze(img_display1(s,:,:))));      
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127;        
        
        if ~isempty(overlay.image) 
          
            % render CTF image onto this plane
            if strcmp(overlay.imageType,'CTF')
                M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel );    
            else
                transforms = getMNITransforms;
                M = transforms.RAS_to_MNI;  
            end
            thisSlice = slice1_big_RAS;
            
            % 1) vox -> ctf coordinates of current plane
            [X, Y, Z] = meshgrid(thisSlice, 1:slice_dim(2), 1:slice_dim(3));
            points = [X(:), Y(:), Z(:)];
            ctf_points = [points, ones(size(points,1),1)]* M;
            ctf_points(:, 4) = [];
            
            % 2) mask for coordinates that exceed bounded box 
            mask = ctf_points(:,1) > overlay.bb(1) & ctf_points(:,1) < overlay.bb(2) & ...
                ctf_points(:,2) > overlay.bb(3) & ctf_points(:,2) < overlay.bb(4) & ...
                ctf_points(:,3) > overlay.bb(5) & ctf_points(:,3) < overlay.bb(6);
            mask = [mask, mask, mask];
            x_plane = ctf_points;
            
            % 3) get coordinates in bounded box coordinate space (minus
            % bounded box offsets and in overlay resolution)
            bb1(1:size(x_plane(:,1),1)) = overlay.bb(1);
            bb2(1:size(x_plane(:,2),1)) = overlay.bb(3);
            bb3(1:size(x_plane(:,3),1)) = overlay.bb(5);
            x_plane(:,1) = round((x_plane(:,1) - bb1')/overlay.RES(1))+1;
            x_plane(:,2) = round((x_plane(:,2) - bb2')/overlay.RES(2))+1;
            x_plane(:,3) = round((x_plane(:,3) - bb3')/overlay.RES(3))+1;
            
            % set coordinates exceeding bounded box to 1,1,1 -- CHANGE?
            x_plane = x_plane.*mask; 
            x_plane(x_plane==0) = 1;
            
            % convert coordinates into indices for overlay image
            Is = size(overlay.image);
            Ioff = cumprod([1 Is(1:end-1)]);
            xidx = (x_plane-1) * Ioff.' + 1;
            
            % get indices into display image (blank image)
            vox_img = zeros(max_dim, max_dim);
            [x, y] = meshgrid(1:max_dim, 1:max_dim);
            vox_points = [x(:), y(:)];
            Is2 = size(vox_img);
            Ioff2 = cumprod([1 Is2(1:end-1)]);
            xidx2 = (vox_points-1) * Ioff2.' + 1;
            
            % render overlay onto display image
%             vox_img(xidx2) = (overlay.image(xidx)/overlay.max)*127.0+128;
            vox_img(xidx2) = (overlay.image(xidx)/overlay.max)*64.0+(128+64);
  
             i = flipdim(vox_img,1);
             vox_img = flipdim(i,2);
                
            imagesc(mdata,[0 255]);
            colormap(cmap);
            
            hold on;

            % influence transparency (allow background image to show
            % through when overlay data low)
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;

            set(im, 'AlphaData', mask);
            hold off;
            
        else            
            imagesc(mdata,[0 127]);
            colormap(gmap);
        end

        % mask image is binary image matching MRI volume
        if ~isempty(maskOverlay.image) 

            colormap(cmap);
            imagesc(mdata,[0 255]);

            hold on;

            % influence transparency (allow background image to show
            % through where overlay data low)
            vox_img = rot90(fliplr(squeeze(maskOverlay.image(s,:,:))));
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;
            set(im, 'AlphaData', mask);
           
            hold off;            
        end

        trad = (1/16:1/8:1)'*2*pi;
        xadd = pt_size*sin(trad);
        yadd = pt_size*cos(trad);
        
        if ~isempty(shape_points)
            hold on;
            x = [];
            y = [];
            if showAllPoints
                idx = 1:size(shape_points_RPI,1);
            else
                idx = find(shape_points_RPI(:,1)==s);
            end
            if ~isempty(idx)
                xpts = shape_points_RPI(idx,2);
                ypts = shape_points_RPI(idx,3);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'green');
            end
            hold off;
        end
        if ~isempty(sensor_points)
            hold on;
            x = [];
            y = [];
            xpts = sensor_points_RPI(:,2);
            ypts = sensor_points_RPI(:,3);
            for i=1:length(xpts)            
                x(:,i) = xpts(i) + xadd;
                y(:,i) = ypts(i) + yadd;               
            end
            patch(x,y,'yellow');           
            hold off;
        end
        
        if ~isempty(surface_points)
            hold on;            
            idx = find(surface_points_RPI(:,1)==s);          
            if ~isempty(idx)
                x = [];
                y = [];
                xpts = surface_points_RPI(idx,2);
                ypts = surface_points_RPI(idx,3);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'red');
                if tail_show && ~isempty(surface_points_orien_RPI)
                    % draw tails
                    xori = surface_points_orien_RPI(idx,2);
                    yori = surface_points_orien_RPI(idx,3);
                    quiver(xpts,ypts, xori, yori,tail_len,'color','y','linewidth',(tail_width));
                end
            end           
            hold off;
        end
        
        if ~isempty(sphereList)
            hold on;            
            % plot mean sphere (is same as single sphere)
            origins = sphereList(:,1:3) * 10.0;  % sphere origin in voxels
            [origin_vox,~] = Head_to_Voxels(origins);
            if isSingleSphere  
                spheresToPlot = 1;
            else
                spheresToPlot = size(sphereList,1);
            end
            for i=1:spheresToPlot
                origin = origin_vox(i,1:3);
                radius_vox = sphereList(i,4) * 10.0 / mmPerVoxel; % radius in voxels
                if(abs(s-origin(1)) < radius_vox)
                    circle_radius = sqrt(radius_vox^2-(s-origin(1))^2);
                    circle_origin = [origin(2) origin(3)];
                    circle(circle_origin,circle_radius,1000,'b-');
                    plot(circle_origin(1),circle_origin(2),'g+');
                end
            end
            hold off;
        end
        
        if ~isempty(dip_params_RPI)
            hold on;
            if showAllDipoles
                idx = 1:size(dip_params_RPI,1);
            else
                idx = find(dip_params_RPI(:,1)==s);   
            end
            if ~isempty(idx)
                % draw filled dots as patches
                xpts = dip_params_RPI(idx,2);
                ypts = dip_params_RPI(idx,3);
                xori = dip_orient_RPI(idx,2);
                yori = dip_orient_RPI(idx,3);
                for i=1:length(xpts)            
                    x = xpts(i) + xadd*2;
                    y = ypts(i) + yadd*2;               
                    col = dipColors{idx(i)};
                    patch(x,y,col);
                end  
                % draw tails
                for i=1:length(xpts)
                    xp = [xpts(i) xpts(i)+xori(i)*10*pt_size];
                    yp = [ypts(i) ypts(i)+yori(i)*10*pt_size];
                    line(xp,yp,'color','y','linewidth',pt_size*2);
                end               
            end
            hold off;          
        end  
        
        image_size = size(mdata);
        
        axis off;
        sag_hor_big = line([1, image_size(1)],[a a],'color',cursor_color);
        sag_ver_big = line([c, c],[1, image_size(2)],'color',cursor_color);
        
        % draw fiducials
        na_RPI = [na_RAS(1)+1 slice_dim(2)-na_RAS(2) slice_dim(3)-na_RAS(3)];
        le_RPI = [le_RAS(1)+1 slice_dim(2)-le_RAS(2) slice_dim(3)-le_RAS(3)];
        re_RPI = [re_RAS(1)+1 slice_dim(2)-re_RAS(2) slice_dim(3)-re_RAS(3)];
        fids = [na_RPI; le_RPI; re_RPI];
        idx = find(fids(:,1)==s);
        if ~isempty(idx)
            hold on;            
            x = [];
            y = [];
            t = (1/16:1/8:1)'*2*pi;
            for i=1:length(idx)            
                x = fid_size*sin(t)+fids(idx(i),2);
                y = fid_size*cos(t)+fids(idx(i),3);
                fill(x,y,orange)                    
            end  
            hold off;        
        end
    end

    function axi_view_big(s,c,a)

        % coordinates in RPI for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        mdata = rot90(fliplr(squeeze(img_display1(:,:,a))));      
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127;        
                
        if ~isempty(overlay.image) 
    
            % render CTF image onto this plane
            if strcmp(overlay.imageType,'CTF')
                M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel );    
            else
                transforms = getMNITransforms;
                M = transforms.RAS_to_MNI;  
            end
            thisSlice = slice3_big_RAS;
              
            % 1) vox -> ctf coordinates of current plane
            [X, Y, Z] = meshgrid(1:slice_dim(1), 1:slice_dim(2), thisSlice);
            points = [X(:), Y(:), Z(:)];
            ctf_points = [points, ones(size(points,1),1)]* M;
            ctf_points(:, 4) = [];
            
            % 2) mask for coordinates that exceed bounded box
            mask = ctf_points(:,1) > overlay.bb(1) & ctf_points(:,1) < overlay.bb(2) & ...
                ctf_points(:,2) > overlay.bb(3) & ctf_points(:,2) < overlay.bb(4) & ...
                ctf_points(:,3) > overlay.bb(5) & ctf_points(:,3) < overlay.bb(6);
            mask = [mask, mask, mask];
            z_plane = ctf_points;
            
            % 3) get coordinates in bounded box coordinate space (minus
            % bounded box offsets and in overlay resolution)
            bb1(1:size(z_plane(:,1),1)) = overlay.bb(1);
            bb2(1:size(z_plane(:,2),1)) = overlay.bb(3);
            bb3(1:size(z_plane(:,3),1)) = overlay.bb(5);
            z_plane(:,1) = round((z_plane(:,1) - bb1')/overlay.RES(1))+1;
            z_plane(:,2) = round((z_plane(:,2) - bb2')/overlay.RES(2))+1;
            z_plane(:,3) = round((z_plane(:,3) - bb3')/overlay.RES(3))+1;
            
            % set coordinates exceeding bounded box to 1,1,1 -- CHANGE?
            z_plane = z_plane.*mask; 
            z_plane(z_plane==0) = 1;
            
            % convert coordinates into indices for overlay image
            Is = size(overlay.image);
            Ioff = cumprod([1 Is(1:end-1)]);
            zidx = (z_plane-1) * Ioff.' + 1;
            
            % get indices into display image (blank image)
            vox_img = zeros(max_dim, max_dim);
            [x, y] = meshgrid(1:max_dim, 1:max_dim);
            vox_points = [x(:), y(:)];
            Is2 = size(vox_img);
            Ioff2 = cumprod([1 Is2(1:end-1)]);
            zidx2 = (vox_points-1) * Ioff2.' + 1;
            
            % render overlay onto display image
%             vox_img(zidx2) = (overlay.image(zidx)/overlay.max)*127.0+128;
            vox_img(zidx2) = (overlay.image(zidx)/overlay.max)*64.0+(128+64);
  
            i = flipdim(vox_img,2);
            vox_img = rot90(fliplr(squeeze(i)));
            
            imagesc(mdata,[0 255]);
            colormap(cmap);
            
            hold on;

            % influence transparency (allow background image to show
            % through when overlay data low)
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;

            set(im, 'AlphaData', mask);
            hold off;
        else            
            imagesc(mdata,[0 127]);
            colormap(gmap);
        end
         
        % mask image is binary image matching MRI volume
        if ~isempty(maskOverlay.image) 

            colormap(cmap);
            imagesc(mdata,[0 255]);

            hold on;

            % influence transparency (allow background image to show
            % through where overlay data low)
            vox_img = rot90(fliplr(squeeze(maskOverlay.image(:,:,a))));          
            im = imagesc(vox_img,[0 255]);
            mask = vox_img > 128;
            mask = mask * overlay.transparency;
            set(im, 'AlphaData', mask);
           
            hold off;            
        end


        trad = (1/16:1/8:1)'*2*pi;
        xadd = pt_size*sin(trad);
        yadd = pt_size*cos(trad);

        if ~isempty(shape_points_RPI)
            hold on;
            x = [];
            y = [];
            if showAllPoints
                idx = 1:size(shape_points_RPI,1);
            else
                idx = find(shape_points_RPI(:,3)==a);
            end
            if ~isempty(idx)
                xpts = shape_points_RPI(idx,1);
                ypts = shape_points_RPI(idx,2);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'green');                   
            end
            hold off;
        end
        if ~isempty(sensor_points)
            hold on;
            x = [];
            y = [];
            xpts = sensor_points_RPI(:,1);
            ypts = sensor_points_RPI(:,2);
            for i=1:length(xpts)            
                x(:,i) = xpts(i) + xadd;
                y(:,i) = ypts(i) + yadd;               
            end
            patch(x,y,'yellow');           
            hold off;
        end
        
        if ~isempty(surface_points)
            hold on;           
            x = [];
            y = [];
            idx = find(surface_points_RPI(:,3)==a); 
            if ~isempty(idx)
                xpts = surface_points_RPI(idx,1);
                ypts = surface_points_RPI(idx,2);
                for i=1:length(xpts)            
                    x(:,i) = xpts(i) + xadd;
                    y(:,i) = ypts(i) + yadd;               
                end  
                patch(x,y,'red');                   
                if tail_show && ~isempty(surface_points_orien_RPI)
                    % draw tails
                    xori = surface_points_orien_RPI(idx,1);
                    yori = surface_points_orien_RPI(idx,2);
                    quiver(xpts,ypts, xori, yori,tail_len,'color','y','linewidth',(tail_width));
                end
            end
            hold off;                    
        end
        
        if ~isempty(sphereList)
            hold on;            
            % plot mean sphere (is same as single sphere)
            origins = sphereList(:,1:3) * 10.0;  % sphere origin in voxels
            [origin_vox,~] = Head_to_Voxels(origins);
            if isSingleSphere  
                spheresToPlot = 1;
            else
                spheresToPlot = size(sphereList,1);
            end
            for i=1:spheresToPlot
                origin = origin_vox(i,1:3);
                radius_vox = sphereList(i,4) * 10.0 / mmPerVoxel; % radius in voxels
                if(abs(a-origin(3)) < radius_vox)
                    circle_radius = sqrt(radius_vox^2-(a-origin(3))^2);
                    circle_origin = [origin(1) origin(2)];
                    circle(circle_origin,circle_radius,1000,'b-');
                    plot(circle_origin(1),circle_origin(2),'g+');
                end
            end
            hold off;
        end   
        
        if ~isempty(dip_params_RPI)
            hold on;
            if showAllDipoles
                idx = 1:size(dip_params_RPI,1);
            else
                idx = find(dip_params_RPI(:,3)==a);   
            end
            if ~isempty(idx)
                % draw filled dots as patches
                xpts = dip_params_RPI(idx,1);
                ypts = dip_params_RPI(idx,2);
                xori = dip_orient_RPI(idx,1);
                yori = dip_orient_RPI(idx,2);
                for i=1:length(xpts)            
                    x = xpts(i) + xadd*2;
                    y = ypts(i) + yadd*2;               
                    col = dipColors{idx(i)};
                    patch(x,y,col);
                end  
                % draw tails
                for i=1:length(xpts)
                    xp = [xpts(i) xpts(i)+xori(i)*10*pt_size];
                    yp = [ypts(i) ypts(i)+yori(i)*10*pt_size];
                    line(xp,yp,'color','y','linewidth',pt_size*2);
                end               
            end
            hold off;          
        end  
        
        image_size = size(mdata);
        
        axis off;
        axi_hor_big=line([1, image_size(1)],[c, c],'color',cursor_color);
        axi_ver_big=line([s, s],[1, image_size(2)],'color',cursor_color);
        
        % draw fiducials
        na_RPI = [na_RAS(1)+1 slice_dim(2)-na_RAS(2) slice_dim(3)-na_RAS(3)];
        le_RPI = [le_RAS(1)+1 slice_dim(2)-le_RAS(2) slice_dim(3)-le_RAS(3)];
        re_RPI = [re_RAS(1)+1 slice_dim(2)-re_RAS(2) slice_dim(3)-re_RAS(3)];
        fids = [na_RPI; le_RPI; re_RPI];
        idx = find(fids(:,3)==a);
        if ~isempty(idx)
            hold on;            
            x = [];
            y = [];
            t = (1/16:1/8:1)'*2*pi;
            for i=1:length(idx)            
                x = fid_size*sin(t)+fids(idx(i),1);
                y = fid_size*cos(t)+fids(idx(i),2);
                fill(x,y,orange)                    
            end  
            hold off;        
        end
    end

    function [mni_pos, label] = getMNICoords(voxel)
        mni_pos = [0 0 0];
        label = '';
        if isempty(transforms)
            return;
        end
        M = transforms.RAS_to_MNI;
        mni_pos =  [voxel 1]  * M;
        mni_pos(4) = [];
        tal_point = round(bw_mni2tal(mni_pos));

        mni_pos = round(mni_pos);

        [~, ~, s3, ~, s5, ~] = bw_get_tal_label(tal_point, 2);
        if (tal_point(1) < 0)
            hemStr = 'L';
        elseif (tal_point(1) > 0 )
            hemStr = 'R';
        else
            hemStr = ' ';
        end

        % if BA returned show as well voxList
        if (strncmp(s5,'Brodmann area', 13))
            BAstr = s5(15:17);
            label = sprintf('%s %s, BA %s', hemStr, s3, BAstr);
        else
            label = sprintf('%s %s', hemStr,  s3);
        end         
    end

    %%%%%%%%%%%%%%%%%%%%%
    % zoom views
    %%%%%%%%%%%%%%%%%%%%%

    function sagaxis_big_view(~,~)
        oldcoords_big = oldcoords;
        slice1_big_RAS = oldcoords_big(1);
        scrsz = get(0,'ScreenSize');
        f_big_sag=figure('Name', 'MRI Viewer Sagittal', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
            'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@stopdrag_sag,'WindowButtonDownFcn',@clickcursor_sag);
        sag_view_big(oldcoords(1),oldcoords(2),oldcoords(3));
        SAGITTAL_SLIDER_BIG = uicontrol('style','slider','units', 'normalized','position',[0.45 0.08 0.4 0.02],'min',1,'max',slice_dim(1),...
            'Value',slice1_big_RAS+1, 'sliderStep', [1 10]/(slice_dim(1)-1),'BackGroundColor',[0.9 0.9 0.9],'callback',@sagittal_slider_big_Callback);
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.4 0.08 0.05 0.02],'String','Left','HorizontalAlignment','left',...
            'BackgroundColor','White','ForegroundColor','red');
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.86 0.08 0.05 0.02],'String','Right','HorizontalAlignment','right',...
            'BackgroundColor','White','ForegroundColor','red');
        sliceStr1 = sprintf('Slice: %d/%d', slice1_big_RAS, slice_dim(1)-1);
        SLICE1_EDIT_BIG = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
            [0.2 0.08 0.15 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
            'BackgroundColor','White', 'enable','on');

        function sagittal_slider_big_Callback(src,~)
            slice1_big_RAS = round(get(src,'Value'))-1;
            sliceStr1 = sprintf('Slice: %d/%d', slice1_big_RAS, slice_dim(1)-1);
            set(SLICE1_EDIT_BIG,'String',sliceStr1);
            oldcoords_big(1)= slice1_big_RAS;
            sag_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
        end
        
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.15 0.03 0.25 0.02],'String','Voxel:','HorizontalAlignment','left',...
            'BackgroundColor','White');
        POSITION_VALUE = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.2 0.03 0.8 0.02],'String',' ','HorizontalAlignment','left',...
            'BackgroundColor','White');
        sag_RAS = oldcoords_big(1);
        cor_RAS = oldcoords_big(2);
        axi_RAS = oldcoords_big(3);
        voxel = [sag_RAS cor_RAS axi_RAS];
        M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);
        meg_pos =  [voxel 1] * M * 0.1;                                              
        [mni_pos, label] = getMNICoords(voxel); 
        sliceStr1 = sprintf('%d %d %d (x= %.1f y= %.1f z= %.1f cm )', sag_RAS,cor_RAS, axi_RAS, meg_pos(1), meg_pos(2), meg_pos(3));
        set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
        function clickcursor_big(~,~)         
            ax = gca;
            set(f_big_sag,'WindowButtonMotionFcn',{@dragCursor,ax}) % need to explicitly pass the axis handle to the motion callback
        end

        function clickcursor_sag(~,~)         
            ax = gca;
            % need to move to current location first...
            posit = round(get(ax,'currentpoint'));
            drawCursor_sag(posit);
            set(f_big_sag,'WindowButtonMotionFcn',{@dragCursor_sag,ax}) % need to explicitly pass the axis handle to the motion callback
        end        
        function dragCursor_sag(~,~, ax)
            posit = round(get(ax,'currentpoint'));
            drawCursor_sag(posit);
        end
        function drawCursor_sag(posit)
            if posit(1,2) <= image_size(1) && posit(1,1) <= image_size(1) && posit(1,2) >= 0 && posit(1,1) >=0
                oldcoords_big=[oldcoords_big(1),slice_dim(2)-posit(1,1),slice_dim(3)-posit(1,2)];
                delete(sag_hor_big);
                delete(sag_ver_big);
                sag_hor_big = line([1, image_size(1)],[slice_dim(3)-oldcoords_big(3), slice_dim(3)-oldcoords_big(3)],'color',cursor_color);
                sag_ver_big = line([slice_dim(2)-oldcoords_big(2), slice_dim(2)-oldcoords_big(2)],[1, image_size(2)],'color',cursor_color);
    
                sag_RAS = oldcoords_big(1);
                cor_RAS = oldcoords_big(2);
                axi_RAS = oldcoords_big(3);
          
                voxel = [sag_RAS cor_RAS axi_RAS];
                M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);
                meg_pos =  [voxel 1] * M * 0.1;                                              
                [mni_pos, label] = getMNICoords(voxel); 

                sliceStr1 = sprintf('%d %d %d MEG: x= %.1f y= %.1f z= %.1f cm, MNI: %d %d %d mm (%s)',...
                    sag_RAS,cor_RAS, axi_RAS, meg_pos(1:3), mni_pos, label);
                set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
            end
        end    
        function stopdrag_sag(~,~)
            set(f_big_sag,'WindowButtonMotionFcn','');
        end
        
        % set fiducials
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.48 0.94 0.08 0.04],'String','Set Na','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_nas_big_callback);
        function set_nas_big_callback(~,~)
            if edit_fids
                na_RAS = [oldcoords_big(1) oldcoords_big(2) oldcoords_big(3)];
                updateFidText;
                sag_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
            else
                s = sprintf('You need to enable Edit option on main window to change fiducial values.');
                warndlg(s);               
            end
        end
        
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.62 0.94 0.08 0.04],'String','Set LE','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_le_big_callback);
        function set_le_big_callback(~,~)
            if edit_fids
                le_RAS = [oldcoords_big(1) oldcoords_big(2) oldcoords_big(3)];
                updateFidText;
                sag_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
            else
                s = sprintf('You need to enable Edit option on main window to change fiducial values.');
                warndlg(s);               
            end
        end
        
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.76 0.94 0.08 0.04],'String','Set RE','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_re_big_callback);
        function set_re_big_callback(~,~)
            if edit_fids
                re_RAS = [oldcoords_big(1) oldcoords_big(2) oldcoords_big(3)];
                updateFidText;
                sag_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
            else
                s = sprintf('You need to enable Edit option on main window to change fiducial values.');
                warndlg(s);               
            end
        end
        
    end

  function coraxis_big_view(~,~)
        oldcoords_big = oldcoords;
        slice2_big_RAS = oldcoords_big(2);
        scrsz = get(0,'ScreenSize');
        
        f_big_cor=figure('Name', 'MRI Viewer Coronal', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
            'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@stopdrag_cor,'WindowButtonDownFcn',@clickcursor_cor);
        cor_view_big(oldcoords(1),oldcoords(2),oldcoords(3));
        uicontrol('style','slider','units', 'normalized','position',[0.45 0.08 0.4 0.02],'min',1,'max',slice_dim(2),...
            'Value',slice_dim(2)-slice2_big_RAS, 'sliderStep', [1 10]/(slice_dim(2)-1),'BackGroundColor',[0.9 0.9 0.9],'callback',@coronal_slider_big_Callback);
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.38 0.08 0.06 0.02],'String','Anterior','HorizontalAlignment','Left',...
            'BackgroundColor','White','ForegroundColor','red');
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.86 0.08 0.08 0.02],'String','Posterior','HorizontalAlignment','Right',...
            'BackgroundColor','White','ForegroundColor','red');
        sliceStr1 = sprintf('Slice: %d/%d', slice2_big_RAS, slice_dim(2)-1);
        SLICE2_EDIT_BIG = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
            [0.2 0.08 0.15 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
            'BackgroundColor','White', 'enable','on');
        
        function coronal_slider_big_Callback(src,~)
            slice2_big_RAS = slice_dim(2)-round(get(src,'Value'));
            sliceStr1 = sprintf('Slice: %d/%d', slice2_big_RAS, slice_dim(2)-1);
            set(SLICE2_EDIT_BIG,'String',sliceStr1);
            oldcoords_big(2)= slice2_big_RAS;
            cor_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
        end
        
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.15 0.03 0.25 0.02],'String','Voxel:','HorizontalAlignment','left',...
            'BackgroundColor','White');
        POSITION_VALUE = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.2 0.03 0.8 0.02],'String',' ','HorizontalAlignment','left',...
            'BackgroundColor','White');
        sag_RAS = oldcoords_big(1);
        cor_RAS = oldcoords_big(2);
        axi_RAS = oldcoords_big(3);
        voxel = [sag_RAS cor_RAS axi_RAS];
        M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);
        meg_pos =  [voxel 1] * M * 0.1;                                              
        [mni_pos, label] = getMNICoords(voxel); 
        sliceStr1 = sprintf('%d %d %d MEG: x= %.1f y= %.1f z= %.1f cm, MNI: %d %d %d mm (%s)',...
            sag_RAS,cor_RAS, axi_RAS, meg_pos(1:3), mni_pos, label);                
        set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
   
        function clickcursor_cor(~,~)         
            ax = gca;
            % need to move to current location first...
            posit = round(get(ax,'currentpoint'));
            drawCursor_cor(posit);
            set(f_big_cor,'WindowButtonMotionFcn',{@dragCursor_cor,ax}) % need to explicitly pass the axis handle to the motion callback
        end       
        function dragCursor_cor(~,~, ax)
            posit = round(get(ax,'currentpoint'));
            drawCursor_cor(posit);            
        end   
        function drawCursor_cor(posit)
            if posit(1,2) <= image_size(1) && posit(1,1) <= image_size(1) && posit(1,2) >= 0 && posit(1,1) >=0
                oldcoords_big=[posit(1,1)-1,oldcoords_big(2),slice_dim(3)-posit(1,2)];
                delete(cor_hor_big);
                delete(cor_ver_big);
                cor_hor_big = line([1, image_size(1)],[slice_dim(3)-oldcoords_big(3), slice_dim(3)-oldcoords_big(3)],'color',cursor_color);
                cor_ver_big = line([oldcoords_big(1)+1, oldcoords_big(1)+1],[1 image_size(2)],'color',cursor_color);

                sag_RAS = oldcoords_big(1);
                cor_RAS = oldcoords_big(2);
                axi_RAS = oldcoords_big(3);
               
                voxel = [sag_RAS cor_RAS axi_RAS];
                M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);
                meg_pos =  [voxel 1] * M * 0.1;                                              
                [mni_pos, label] = getMNICoords(voxel); 

                sliceStr1 = sprintf('%d %d %d MEG: x= %.1f y= %.1f z= %.1f cm, MNI: %d %d %d mm (%s)',...
                    sag_RAS,cor_RAS, axi_RAS, meg_pos(1:3), mni_pos, label);
                set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
            end
        end
        function stopdrag_cor(~,~)
            set(f_big_cor,'WindowButtonMotionFcn','');
        end  
        
        % set fiducials
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.48 0.94 0.08 0.04],'String','Set Na','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_nas_big_callback);
        function set_nas_big_callback(~,~)
            if edit_fids
                na_RAS = [oldcoords_big(1) oldcoords_big(2) oldcoords_big(3)];
                updateFidText;
                cor_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
            else
                s = sprintf('You need to enable Edit option on main window to change fiducial values.');
                warndlg(s);
                
            end
        end
        
         uicontrol('style','pushbutton','units','normalized','Position',...
            [0.62 0.94 0.08 0.04],'String','Set LE','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_le_big_callback);
        function set_le_big_callback(~,~)
            if edit_fids
                le_RAS = [oldcoords_big(1) oldcoords_big(2) oldcoords_big(3)];
                updateFidText;
                cor_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
            else
                s = sprintf('You need to enable Edit option on main window to change fiducial values.');
                warndlg(s);
                
            end
        end
        
         uicontrol('style','pushbutton','units','normalized','Position',...
            [0.76 0.94 0.08 0.04],'String','Set RE','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_re_big_callback);
        function set_re_big_callback(~,~)
            if edit_fids
                re_RAS = [oldcoords_big(1) oldcoords_big(2) oldcoords_big(3)];
                updateFidText;
                cor_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
            else
                s = sprintf('You need to enable Edit option on main window to change fiducial values.');
                warndlg(s);
                
            end
        end
        
  end

 function axiaxis_big_view(~,~)
        oldcoords_big = oldcoords;
        slice3_big_RAS = oldcoords_big(3);
        scrsz = get(0,'ScreenSize');
        
        f_big_axi=figure('Name', 'MRI Viewer Axial', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
            'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@stopdrag_axi,'WindowButtonDownFcn',@clickcursor_axi);
        axi_view_big(oldcoords(1),oldcoords(2),oldcoords(3));
        uicontrol('style','slider','units', 'normalized','position',[0.45 0.08 0.4 0.02],'min',1,'max',slice_dim(3),...
            'Value',slice_dim(3)-slice3_big_RAS, 'sliderStep', [1 10]/(slice_dim(3)-1),'BackGroundColor',[0.9 0.9 0.9],'callback',@axial_slider_big_Callback);
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.38 0.08 0.06 0.02],'String','Superior','HorizontalAlignment','Left',...
            'BackgroundColor','White','ForegroundColor','red');
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.86 0.08 0.08 0.02],'String','Inferior','HorizontalAlignment','Right',...
            'BackgroundColor','White','ForegroundColor','red');
          sliceStr1 = sprintf('Slice: %d/%d', slice3_big_RAS, slice_dim(3)-1);
        SLICE3_EDIT_BIG = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
            [0.2 0.08 0.15 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
            'BackgroundColor','White', 'enable','on');
        
        function axial_slider_big_Callback(src,~)
            slice3_big_RAS = slice_dim(3)-round(get(src,'Value'));
            sliceStr1 = sprintf('Slice: %d/%d', slice3_big_RAS, slice_dim(3)-1);
            set(SLICE3_EDIT_BIG,'String',sliceStr1);
            oldcoords_big(3)= slice3_big_RAS;
            axi_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
        end
        
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.15 0.03 0.25 0.02],'String','Voxel:','HorizontalAlignment','left',...
            'BackgroundColor','White');
        POSITION_VALUE = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.2 0.03 0.8 0.02],'String',' ','HorizontalAlignment','left',...
            'BackgroundColor','White');
        sag_RAS = oldcoords_big(1);
        cor_RAS = oldcoords_big(2);
        axi_RAS = oldcoords_big(3);
      
        voxel = [sag_RAS cor_RAS axi_RAS];
        M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);
        meg_pos =  [voxel 1] * M * 0.1;                                              
        [mni_pos, label] = getMNICoords(voxel); 

        sliceStr1 = sprintf('%d %d %d MEG: x= %.1f y= %.1f z= %.1f cm, MNI: %d %d %d mm (%s)',...
            sag_RAS,cor_RAS, axi_RAS, meg_pos(1:3), mni_pos, label);
        set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
        
        function clickcursor_axi(~,~)         
            ax = gca;
            % need to move to current location first...
            posit = round(get(ax,'currentpoint'));
            drawCursor_axi(posit);
            set(f_big_axi,'WindowButtonMotionFcn',{@dragCursor_axi,ax}) % need to explicitly pass the axis handle to the motion callback
        end
        function dragCursor_axi(~,~, ax)
            posit = round(get(ax,'currentpoint'));
            drawCursor_axi(posit);
        end       
    	function drawCursor_axi(posit)
            if posit(1,2) <= image_size(1) && posit(1,1) <= image_size(1) && posit(1,2) >= 0 && posit(1,1) >=0
                oldcoords_big=[posit(1,1)-1,slice_dim(2)-posit(1,2),oldcoords_big(3)];
                delete(axi_hor_big);
                delete(axi_ver_big);
                axi_hor_big=line([1, image_size(1)],[slice_dim(2)-oldcoords_big(2), slice_dim(2)-oldcoords_big(2)],'color',cursor_color);
                axi_ver_big=line([oldcoords_big(1)+1, oldcoords_big(1)+1],[1, image_size(2)],'color',cursor_color);
                
                sag_RAS = oldcoords_big(1);
                cor_RAS = oldcoords_big(2);
                axi_RAS = oldcoords_big(3);

                voxel = [sag_RAS cor_RAS axi_RAS];
                M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);
                meg_pos =  [voxel 1] * M * 0.1;                                              
                [mni_pos, label] = getMNICoords(voxel); 

                sliceStr1 = sprintf('%d %d %d MEG: x= %.1f y= %.1f z= %.1f cm, MNI: %d %d %d mm (%s)',...
                    sag_RAS,cor_RAS, axi_RAS, meg_pos(1:3), mni_pos, label);
                set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
            end            
        end
        
        function stopdrag_axi(~,~)
            set(f_big_axi,'WindowButtonMotionFcn','');
        end
        
        % set fiducials
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.48 0.94 0.08 0.04],'String','Set Na','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_nas_big_callback);
        function set_nas_big_callback(~,~)
            if edit_fids
                na_RAS = [oldcoords_big(1) oldcoords_big(2) oldcoords_big(3)];
                updateFidText;
                axi_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
            else
                s = sprintf('You need to enable Edit option on main window to change fiducial values.');
                warndlg(s);               
            end
        end
        
         uicontrol('style','pushbutton','units','normalized','Position',...
            [0.62 0.94 0.08 0.04],'String','Set LE','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_le_big_callback);
        function set_le_big_callback(~,~)
            if edit_fids
                le_RAS = [oldcoords_big(1) oldcoords_big(2) oldcoords_big(3)];
                updateFidText;
                axi_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
            else
                s = sprintf('You need to enable Edit option on main window to change fiducial values.');
                warndlg(s);              
            end
        end
        
         uicontrol('style','pushbutton','units','normalized','Position',...
            [0.76 0.94 0.08 0.04],'String','Set RE','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_re_big_callback);
        function set_re_big_callback(~,~)
            if edit_fids
                re_RAS = [oldcoords_big(1) oldcoords_big(2) oldcoords_big(3)];
                updateFidText;
                axi_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
            else
                s = sprintf('You need to enable Edit option on main window to change fiducial values.');
                warndlg(s);            
            end
        end
        
 end


    %%%%%%%%%%%% end display %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function updateDisplay
        % update display
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));     
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));     
    end

%%%%%%
    function circle(center, radius, NOP, style)
        THETA=linspace(0,2*pi,NOP);
        RHO=ones(1,NOP)*radius;
        [X,Y] = pol2cart(THETA,RHO);
        X=X+center(1);
        Y=Y+center(2);
        plot(X,Y,style,'LineWidth',1.5);
    end

    function buttondown(~,~)         
        ax = gca;
        % need to move to current location first...
        posit = round(get(ax,'currentpoint'));
        drawCursor(ax,posit);
        % update drawing while cursor being dragged
        set(f,'WindowButtonMotionFcn',{@dragCursor,ax}) % need to explicitly pass the axis handle to the motion callback
    end
 
    % button down function - drag cursor
    function dragCursor(~,~, ax)
        mousecoord = get(ax,'currentpoint');
        posit = round(mousecoord);         
        drawCursor(ax,posit);
    end
    
    % on button up event set motion event back to no callback 
    function stopdrag(~,~)
        set(f,'WindowButtonMotionFcn','');
    end
 
    function drawCursor(ax,posit)
        switch ax
            case sagaxis
                if posit(1,1) < 1 || posit(1,1) > slice_dim(2) || posit(1,2) < 1 || posit(1,2) > slice_dim(3)
                    return;
                end
                oldcoords=[oldcoords(1),slice_dim(2)-posit(1,1),slice_dim(3)-posit(1,2)];
            case coraxis
                if posit(1,1) < 1 || posit(1,1) > slice_dim(1) || posit(1,2) < 1 || posit(1,2) > slice_dim(3)
                    return;
                end
                oldcoords=[posit(1,1)-1,oldcoords(2),slice_dim(3)-posit(1,2)];
            case axiaxis
                if posit(1,1) < 1 || posit(1,1) > slice_dim(1) || posit(1,2) < 1 || posit(1,2) > slice_dim(2)
                    return;
                end
                oldcoords=[posit(1,1)-1,slice_dim(2)-posit(1,2),oldcoords(3)];
            otherwise
        end
 
        slice1_RAS=oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', oldcoords(1)+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-oldcoords(2));
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-oldcoords(3));
 
        updateDisplay;
 
    end

    function updateCursorText 
        x=oldcoords(1);
        y=oldcoords(2);
        z=oldcoords(3);
                     
        M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel);
        meg_pos_mm =  [x y z 1] * M;
        meg_pos =  meg_pos_mm * 0.1;
        if ~isempty(transforms)
            M = transforms.RAS_to_MNI;
            mni_pos =  [x y z 1]  * M;
            mni_pos(4) = [];
            tal_point = round(bw_mni2tal(mni_pos));

            [~, ~, s3, ~, s5, ~] = bw_get_tal_label(tal_point, 2);
            if (tal_point(1) < 0)
                hemStr = 'L';
            elseif (tal_point(1) > 0 )
                hemStr = 'R';
            else
                hemStr = ' ';
            end

            % if BA returned show as well voxList
            if (strncmp(s5,'Brodmann area', 13))
                BAstr = s5(15:17);
                label = sprintf('%s %s, BA %s', hemStr, s3, BAstr);
            else
                label = sprintf('%s %s', hemStr,  s3);
            end         
        else
           mni_pos = [];
        end

        if ~isempty(overlay.image)                 
 
            if strcmp(overlay.imageType,'MNI')
               voxel_pos =  mni_pos;
            else    
               voxel_pos =  meg_pos_mm;
            end    
            % get value at SAM voxel
            xv = round( ((voxel_pos(1)) - overlay.bb(1) ) / overlay.RES(1) ) + 1;
            yv = round( ((voxel_pos(2)) - overlay.bb(3) ) / overlay.RES(2) ) + 1;
            zv = round( ((voxel_pos(3)) - overlay.bb(5) ) / overlay.RES(3) ) + 1;               
        
            if xv > 0 && xv < overlay.DIM(1) && yv > 0 && yv < overlay.DIM(2) && zv > 0 && zv < overlay.DIM(3)
                mag = overlay.data(xv, yv, zv);
            else
                mag = 0.0;
            end                
           
            str = sprintf('MEG coord: x = %.1f y = %.1f z = %.1f cm', meg_pos(1), meg_pos(2), meg_pos(3) );
            set(CURSOR_TEXT,'String',str,'ForegroundColor',orange); 

            str = sprintf('MNI coord: %d %d %d mm (%s), Magnitude = %.2f', round(mni_pos(1)), round(mni_pos(2)), round(mni_pos(3)), label, mag);
            set(CURSOR_TEXT2,'String',str,'ForegroundColor',orange); 
        else
            if ~isempty(mni_pos)
                str = sprintf('MEG coord: x = %.1f y = %.1f z = %.1f cm', meg_pos(1), meg_pos(2), meg_pos(3) );
                set(CURSOR_TEXT,'String',str,'ForegroundColor',orange); 
    
                str = sprintf('MNI coord: %d %d %d mm (%s)', round(mni_pos(1)), round(mni_pos(2)), round(mni_pos(3)), label);
                set(CURSOR_TEXT2,'String',str,'ForegroundColor',orange); 
            else
                str = sprintf('MEG: x=%.1f y=%.1f z=%.1f cm', meg_pos(1), meg_pos(2), meg_pos(3));          
                set(CURSOR_TEXT,'String',str,'ForegroundColor',orange);  
            end
        end

         
    end
        

SAGITTAL_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.64 0.52 0.2 0.02],'min',1,'max',slice_dim(1),...
    'Value',slice1_RAS+1, 'sliderStep', [1 20]/(slice_dim(1)-1),'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@sagittal_slider_Callback);

uicontrol('Style','Text','FontSize',9,'Units','Normalized','Position',...
    [0.575 0.55 0.2 0.02],'String','A','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','red');
uicontrol('Style','Text','FontSize',9,'Units','Normalized','Position',...
    [0.7 0.55 0.2 0.02],'String','P','HorizontalAlignment','right',...6
    'BackgroundColor','White','ForegroundColor','red');


sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
SLICE1_EDIT = uicontrol('Style','Text','FontSize',9,'Units','Normalized','Position',...
    [0.68 0.55 0.2 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
    'BackgroundColor','White', 'enable','off');


uicontrol('style','text','units','normalized','position',[0.59 0.49 0.04 0.05],...
    'string','Left','fontsize',9,'background','white');

uicontrol('style','text','units','normalized','position',[0.85 0.49 0.04 0.05],...
    'string','Right','fontsize',9,'background','white');


    function sagittal_slider_Callback(src,~)
        slice1_RAS = round(get(src,'Value'))-1;
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        oldcoords(1)= slice1_RAS;
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        updateCrosshairs(oldcoords(1),oldcoords(2),oldcoords(3));
    end

CORONAL_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.19 0.52 0.2 0.02],'min',1,'max',slice_dim(2),...
    'Value',slice_dim(2)-slice2_RAS, 'sliderStep', [1 20]/(slice_dim(2)-1),'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@coronal_slider_Callback);

uicontrol('Style','Text','FontSize',9,'Units','Normalized','Position',...
    [0.135 0.55 0.2 0.02],'String','L','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','red');
uicontrol('Style','Text','FontSize',9,'Units','Normalized','Position',...
    [0.26 0.55 0.2 0.02],'String','R','HorizontalAlignment','right',...
    'BackgroundColor','White','ForegroundColor','red');

sliceStr1 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
SLICE2_EDIT = uicontrol('Style','Text','FontSize',9,'Units','Normalized','Position',...
    [0.24 0.55 0.2 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
    'BackgroundColor','White', 'enable','off');

uicontrol('style','text','units','normalized','position',[0.105 0.51 0.08 0.03],...
    'string','Anterior','fontsize',9,'background','white');

uicontrol('style','text','units','normalized','position',[0.4 0.51 0.08 0.03],...
    'string','Posterior','fontsize',9,'background','white');


    function coronal_slider_Callback(src,~)
        slice2_RAS = slice_dim(2)-round(get(src,'Value'));
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        oldcoords(2)= slice2_RAS;
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        updateCrosshairs(oldcoords(1),oldcoords(2),oldcoords(3));
    end

AXIS_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.19 0.05 0.2 0.02],'min',1,'max',slice_dim(3),...
    'Value',slice_dim(3)-slice3_RAS, 'sliderStep', [1 20]/(slice_dim(3)-1),'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@axis_slider_Callback);

uicontrol('Style','Text','FontSize',9,'Units','Normalized','Position',...
    [0.135 0.08 0.2 0.02],'String','L','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','red');
uicontrol('Style','Text','FontSize',9,'Units','Normalized','Position',...
    [0.26 0.08 0.2 0.02],'String','R','HorizontalAlignment','right',...
    'BackgroundColor','White','ForegroundColor','red');

sliceStr1 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
SLICE3_EDIT = uicontrol('Style','Text','FontSize',9,'Units','Normalized','Position',...
        [0.24 0.08 0.2 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
        'BackgroundColor','White', 'enable','off');
    
uicontrol('style','text','units','normalized','position',[0.105 0.05 0.08 0.02],...
    'string','Superior','fontsize',9,'background','white');

uicontrol('style','text','units','normalized','position',[0.39 0.05 0.08 0.02],...
    'string','Inferior','fontsize',9,'background','white');


    function axis_slider_Callback(src,~)
        slice3_RAS = slice_dim(3)-round(get(src,'Value'));
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        oldcoords(3)= slice3_RAS;
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        updateCrosshairs(oldcoords(1), oldcoords(2), oldcoords(3));
    end

uicontrol('style','pushbutton','units','normalized','Position',...
    [0.8 0.55 0.06 0.025],'String','Zoom','BackgroundColor','white',...
    'FontSize',9,'callback',@sagaxis_big_view);

uicontrol('style','pushbutton','units','normalized','Position',...
    [0.36 0.55 0.06 0.025],'String','Zoom','BackgroundColor','white',...
    'FontSize',9,'callback',@coraxis_big_view);

uicontrol('style','pushbutton','units','normalized','Position',...
    [0.36 0.08 0.06 0.025],'String','Zoom','BackgroundColor','white',...
    'FontSize',9,'callback',@axiaxis_big_view);



%%%%%%%%%%%%%%%%%%%%%%
% Fiducial Controls
%%%%%%%%%%%%%%%%%%%%%%

uicontrol('style','checkbox','units','normalized','Position',...
    [0.82 0.46 0.18 0.035],'String','Show All Markers','BackgroundColor','white','value',showAllPoints,...
    'fontsize',10,'callback',@show_all_callback);
    function show_all_callback(src,~)
        showAllPoints = get(src,'val');
        updateDisplay;
    end

annotation('rectangle',[0.5 0.185 0.49 0.26],'Color','blue');

uicontrol('style','text','units','normalized','Position',...
    [0.66 0.435 0.12 0.02],'String','Fiducials','BackgroundColor','white',...
    'FontSize',9,'ForegroundColor','blue');

uicontrol('style','checkbox','units','normalized','Position',...
    [0.52 0.4 0.12 0.035],'String','Edit','BackgroundColor','white','value',0,...
    'fontsize',10,'callback',@edit_fid_callback);


uicontrol('style','pushbutton','units','normalized','Position',...
    [0.89 0.36 0.08 0.035],'String',' View Na','BackgroundColor','white',...
    'FontSize',9,'ForegroundColor','blue','callback',@nasion_but_callback);
    function nasion_but_callback(~,~)        
        oldcoords=[na_RAS(1),na_RAS(2),na_RAS(3)];
        slice1_RAS = oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', slice1_RAS+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-slice2_RAS);
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-slice3_RAS);
        updateDisplay;

    end
uicontrol('style','pushbutton','units','normalized','Position',...
    [0.89 0.31 0.08 0.035],'String','View LE','BackgroundColor','white',...
    'FontSize',9,'ForegroundColor','blue','callback',@lear_but_callback);
    function lear_but_callback(~,~)

        oldcoords=[le_RAS(1),le_RAS(2),le_RAS(3)];
        slice1_RAS=oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', slice1_RAS+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-slice2_RAS);
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-slice3_RAS);
                   
        updateDisplay;
    end

uicontrol('style','pushbutton','units','normalized','Position',...
    [0.89 0.26 0.08 0.035],'String','View RE','BackgroundColor','white',...
    'FontSize',9,'ForegroundColor','blue','callback',@rear_but_callback);
    function rear_but_callback(~,~)
        oldcoords=[re_RAS(1),re_RAS(2),re_RAS(3)];
        slice1_RAS=oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', slice1_RAS+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-slice2_RAS);
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-slice3_RAS);
                    
        updateDisplay;
    end

%edit boxes with fiducial coords
nas_s=uicontrol('style','edit','units','normalized','position',...
    [0.63 0.36 0.08 0.035],'String', na_RAS(1),...
    'fontsize',10, 'BackGroundColor','white','callback',@nas_s_callback);

    function nas_s_callback(src,~)
        na_RAS(1)=str2double(get(src,'string'));
        nasion_but_callback;
    end

nas_c=uicontrol('style','edit','units','normalized','position',...
    [0.715 0.36 0.08 0.035],'String', na_RAS(2),...
    'fontsize',10, 'BackGroundColor','white','callback',@nas_c_callback);

    function nas_c_callback(src,~)
        na_RAS(2)=str2double(get(src,'string'));
        nasion_but_callback;
    end

nas_a=uicontrol('style','edit','units','normalized','position',...
    [0.8 0.36 0.08 0.035],'String', na_RAS(3),...
    'fontsize',10, 'BackGroundColor','white','callback',@nas_a_callback);

    function nas_a_callback(src,~)
        na_RAS(3)=str2double(get(src,'string'));
        nasion_but_callback;
    end

lear_s=uicontrol('style','edit','units','normalized','position',...
    [0.63 0.31 0.08 0.035],'String', le_RAS(1),...
    'fontsize',10, 'BackGroundColor','white','callback',@lear_s_callback);

    function lear_s_callback(src,~)
        le_RAS(1)=str2double(get(src,'string'));
        lear_but_callback;
    end

lear_c=uicontrol('style','edit','units','normalized','position',...
    [0.715 0.31 0.08 0.035],'String', le_RAS(2),...
    'fontsize',10, 'BackGroundColor','white','callback',@lear_c_callback);

    function lear_c_callback(src,~)
        le_RAS(2)=str2double(get(src,'string'));
        lear_but_callback;
    end

lear_a=uicontrol('style','edit','units','normalized','position',...
    [0.8 0.31 0.08 0.035],'String', le_RAS(3),...
    'fontsize',10, 'BackGroundColor','white','callback',@lear_a_callback);

    function lear_a_callback(src,~)
        le_RAS(3)=str2double(get(src,'string'));
        lear_but_callback;
    end

rear_s=uicontrol('style','edit','units','normalized','position',...
    [0.63 0.26 0.08 0.035],'String', re_RAS(1),...
    'fontsize',10, 'BackGroundColor','white','callback',@rear_s_callback);

    function rear_s_callback(src,~)
        re_RAS(1)=str2double(get(src,'string'));
        rear_but_callback;
    end

rear_c=uicontrol('style','edit','units','normalized','position',...
    [0.715 0.26 0.08 0.035],'String', re_RAS(2),...
    'fontsize',10, 'BackGroundColor','white','callback',@rear_c_callback);

    function rear_c_callback(src,~)
        re_RAS(2)=str2double(get(src,'string'));  
        rear_but_callback;
    end

rear_a=uicontrol('style','edit','units','normalized','position',...
    [0.8 0.26 0.08 0.035],'String', re_RAS(3),...
    'fontsize',10, 'BackGroundColor','white','callback',@rear_a_callback);

    function rear_a_callback(src,~)
        re_RAS(3)=str2double(get(src,'string'));  
        rear_but_callback;
    end

%button for setting new
set_nas=uicontrol('style','pushbutton','units','normalized','Position',...
    [0.52 0.36 0.1 0.035],'String','Set Na','BackgroundColor','white',...
    'FontSize',9,'ForegroundColor','red','callback',@set_nas_callback);
    function set_nas_callback(~,~)
        na_RAS = [oldcoords(1) oldcoords(2) oldcoords(3)];
        updateFidText;
        updateDisplay;
    end

set_lear=uicontrol('style','pushbutton','units','normalized','Position',...
    [0.52 0.31 0.1 0.035],'String','Set LE','BackgroundColor','white',...
    'FontSize',9,'ForegroundColor','red','callback',@set_lear_callback);
    function set_lear_callback(~,~)
        le_RAS = [oldcoords(1) oldcoords(2) oldcoords(3)];
        updateFidText;
        updateDisplay;
    end

set_rear=uicontrol('style','pushbutton','units','normalized','Position',...
    [0.52 0.26 0.1 0.035],'String','Set RE','BackgroundColor','white',...
    'FontSize',9,'ForegroundColor','red','callback',@set_rear_callback);
    function set_rear_callback(~,~)
        re_RAS = [oldcoords(1) oldcoords(2) oldcoords(3)];
        updateFidText;
        updateDisplay;
    end
           

sagittal_text=uicontrol('style','text','units','normalized','position',[0.65 0.4 0.06 0.03],...
    'string','L - R','fontsize',10,'FontWeight','normal','background','white','callback',@set_sagittal_callback);
    function set_sagittal_callback(~,~)
        set(sagittal_text,'string','L->R');
    end
coronal_text=uicontrol('style','text','units','normalized','position',[0.73 0.4 0.06 0.03],...
    'string','P - A','fontsize',10,'FontWeight','normal','background','white','callback',@set_coronal_callback);
    function set_coronal_callback(~,~)
        set(coronal_text,'string','P->A');      
    end
axis_text=uicontrol('style','text','units','normalized','position',[0.81 0.4 0.06 0.03],...
    'string','I - S','fontsize',10,'FontWeight','normal','background','white','callback',@set_axis_callback);
    function set_axis_callback(~,~)
         set(axis_text,'string','I->S');
    end

undo_changes=uicontrol('style','pushbutton','units','normalized','Position',...
    [0.65 0.21 0.12 0.035],'String','Undo Changes','BackgroundColor','white',...
    'FontSize',10,'ForegroundColor','red','callback',@undo_changes_callback);
    function undo_changes_callback(~,~)

        matFileName = strrep(mriName, '.nii', '.mat');
        fprintf('Setting fiducials to values in %s ...\n', matFileName);
        fid=fopen(matFileName);
        if (fid>0)
            fd=load(matFileName);
            na_RAS= fd.na;
            le_RAS= fd.le;
            re_RAS= fd.re;

        else
            na_RAS=[0 0 0]; %default values if no fiducial information included
            le_RAS=[0 0 0];
            re_RAS=[0 0 0];
        end
        
        updateFidText;
        
        % need to update display 
        updateDisplay;        
        
    end

    function updateFidText
        set(nas_s,'string',na_RAS(1));
        set(nas_c,'string',na_RAS(2));
        set(nas_a,'string',na_RAS(3));
        set(lear_s,'string',le_RAS(1));
        set(lear_c,'string',le_RAS(2));
        set(lear_a,'string',le_RAS(3));
        set(rear_s,'string',re_RAS(1));
        set(rear_c,'string',re_RAS(2));
        set(rear_a,'string',re_RAS(3));
    end

save_changes=uicontrol('style','pushbutton','units','normalized','Position',...
    [0.52 0.21 0.12 0.035],'String','Save Fiducials','BackgroundColor','white',...
    'FontSize',9,'ForegroundColor','red','callback',@save_change_fiducials_callback);


    function edit_fid_callback(src,~)
        edit_fids = get(src,'value');
        if edit_fids
            set(set_nas, 'enable','on');
            set(set_lear, 'enable','on');
            set(set_rear, 'enable','on');            
            set(undo_changes, 'enable','on');            
            set(save_changes, 'enable','on');
        else
            set(set_nas, 'enable','off');
            set(set_lear, 'enable','off');
            set(set_rear, 'enable','off');            
            set(undo_changes, 'enable','off');            
            set(save_changes, 'enable','off');            
        end
    end

    % read head model file and set global variables
    % version 4.0 - eliminate reading of CTF version - not needed
    function loadHeadModelFile(hdmFile)
                
        fid = fopen(hdmFile,'r');
        if fid == -1
            error('Unable to open head model file.');
        end

        A = textscan(fid,'%s%s%s%s%s');
        fclose(fid);               
        sphereChanList = A{1};
        % strip colons from channel names   
        for i=1:size(sphereChanList,1)
            x = sphereChanList{i};
            sphereChanList{i} = x(1:end-1);
        end
        sphereList=str2double([A{2} A{3} A{4} A{5}]);

        sphere_o(1) = mean(sphereList(:,1));
        sphere_o(2) = mean(sphereList(:,2));
        sphere_o(3) = mean(sphereList(:,3));
        sphere_r = mean(sphereList(:,4));   

        % set flag to indicate whether all spheres are the same
        % i.e., singleSphere or multiSphere model
        if size(unique(sphereList(:,1))) == 1 & size(unique(sphereList(:,2))) == 1 & size(unique(sphereList(:,3))) == 1
            isSingleSphere = 0;
            fprintf('Read single sphere Model: origin = %.2f %.2f %.2f cm, radius = %.2f cm\n', sphere_o, sphere_r);        
        else
            fprintf('Read multiple sphere Model: Mean Sphere origin = %.2f %.2f %.2f cm, radius = %.2f cm\n', sphere_o, sphere_r);
            isSingleSphere = 1;
        end 
    end


% set initial state for controls
set(set_nas, 'enable','off');
set(set_lear, 'enable','off');
set(set_rear, 'enable','off');            
set(undo_changes, 'enable','off');            
set(save_changes, 'enable','off'); 

 
    function fit_sphere_callback(~,~)
        if isempty(shape_points)   
            errordlg('You must load a shape file to do sphere fitting');
            return;
        end

        fprintf('Generating single sphere head model (.hdm) file...\n');
        pts = shape_points * 0.1;  % pass shape in cm
        [sphere_o, sphere_r] = bw_fitSphere(double(pts));

        % create dummy sphereList to show origin after fitting
        sphereList = [sphere_o(1) sphere_o(2) sphere_o(3) sphere_r];        
        updateDisplay;
        
        tstr = sprintf('Single-sphere fit complete: origin = %.2f %.2f %.2f cm, radius = %.2f cm. Write model to datasets?\n', sphere_o, sphere_r);
        fprintf(tstr);

       
        response = questdlg(tstr, 'Head Models','Yes','No','Yes');
        if strcmp(response,'No')
            sphereList = [];        
            updateDisplay;
            return;
        end
        
        filepath = pwd;
        ds_fullname=uigetdir2(filepath,'Select Dataset(s)...');
        if isempty(ds_fullname)
            return;
        end

        nn = length(ds_fullname);
        ds_Path=cell(1,nn);
        ds_Name=cell(1,nn);
        ds_EXT=cell(1,nn);
        
        hdmFile = fullfile(ds_fullname{1},'singleSphere.hdm');
        [hdmName, hdmPath] = uiputfile('singleSphere.hdm','Save the head model file',hdmFile);       
        if isequal(hdmName,0) || isequal(hdmPath,0)
            return;
        end
        
        for k=1:nn
            [ds_Path{k},ds_Name{k},ds_EXT{k}] = fileparts(ds_fullname{k});
            names=[];
            chan_names{k}= {' '};
            
            if (strcmp(ds_EXT{k},'.ds')==0)
                warndlg('You need to choose the dataset files.');
                return;
            end
            if ~isempty(file_name)&&(strcmp(ds_Name{k}(1:2),file_name(1:2))==0)
                response = questdlg('Warning: Subject ID of the dataset does not match subject ID for this MRI. Proceed?',...
                    'Save  Head Model','Yes','No','Yes');
                if strcmp(response,'No')
                    return;
                end
            end
                    
            [chan_names{k}, chan_pos{k}, ~] = bw_CTFGetSensors(ds_fullname{k}, 1);
            for i=1:size(chan_names{k},1)
                xx = chan_names{k}(i,:);
                idx = strfind(xx,'-');
                if ~isempty(idx)
                    names{i} = xx(1:idx-1);
                else
                    names{i} = xx;
                end
            end
                 
            hdm_File = fullfile(ds_fullname{k}, hdmName);
            
            
            fprintf('\nSaving best-fit single sphere in %s\n',hdm_File);
            fid = fopen(hdm_File,'w');
            % create a channel and sphere list for saving...
            for i=1:size(chan_names{k},1)
                s = char(names{i});
                fprintf(fid, '%s:    %.3f    %.3f    %.3f    %.3f\n', s, sphere_o, sphere_r);
            end
            
            fclose(fid);
            clear ds_Path{k} ds_Name{k} ds_EXT{k} chan_names{k};
            
        end
 
        % load saved head model - updates sphereList and sets flag for singe or multi
        loadHeadModelFile(hdm_File);
        updateDisplay;

        s = sprintf('Spherical model saved to %d dataset(s)', nn);
        msgbox(s);
    
    end

    function multiplefit_sphere_callback(~,~)
        if isempty(shape_points)
            errordlg('You must load a shape file to do multiple sphere fitting');
            return;
        else           
            patch_size = 9.0;
            input = inputdlg({'Enter Patch size for multiple sphere fit (in cm)'},'Multisphere Fit',[1 100], {num2str(patch_size)});
            if isempty(input)
                return;                
            end 
            patch_size = str2double(input{1});

            
            filepath = pwd;
            ds_fullname=uigetdir2(filepath,'Select Datasets...');
            if isempty(ds_fullname)
                return;
            end
            nn = length(ds_fullname);
            ds_Path=cell(1,nn);
            ds_Name=cell(1,nn);
            ds_EXT=cell(1,nn);
            
            hdmFile = fullfile(ds_fullname{1},'multipleSphere.hdm');
            [hdmName, hdmPath] = uiputfile('multipleSphere.hdm','Save the head model file',hdmFile);
            
            if isequal(hdmName,0) || isequal(hdmPath,0)
                return;
            end
            
            for k=1:nn
                [ds_Path{k},ds_Name{k},ds_EXT{k}] = fileparts(ds_fullname{k});
                names=[];
                chan_names{k}= {' '};
                chan_pos{k}=[];
                
                if (strcmp(ds_EXT{k},'.ds')==0)
                    warndlg('You need to choose the dataset files.');
                    return;
                end
                if ~isempty(file_name)&&(strcmp(ds_Name{k}(1:2),file_name(1:2))==0)
                response = questdlg('Warning: Subject ID of the dataset does not match subject ID for this MRI. Proceed?',...
                        'Save  Head Model','Yes','No','Yes');
                    if strcmp(response,'No')
                        return;
                    end                
                end
                
                
                [chan_names{k}, chan_pos{k}, ~] = bw_CTFGetSensors(ds_fullname{k}, 1);
                for i=1:size(chan_names{k},1)
                    idx=[];
                    xx = chan_names{k}(i,:);
                    idx = strfind(xx,'-');
                    if ~isempty(idx)
                        names{i} = xx(1:idx-1);
                    else
                        names{i} = xx;
                    end
                end
                
                hdm_File = fullfile(ds_fullname{k}, hdmName);
                
                
                fprintf('Generating multiple (overlapping spheres) head model (.hdm) file using patch radius of %g cm...\n',patch_size);
                
                pts = shape_points * 0.1;  % pass shape in cm
                
                [sphere_o, sphere_r, err] = bw_fitMultipleSpheres(ds_fullname{k}, pts, names, chan_pos{k}, hdm_File, patch_size);
                if (err == 0)
                    fprintf('Mean sphere single sphere: origin = %.2f %.2f %.2f cm, radius = %.2f cm\n', sphere_o, sphere_r);
                end

                clear ds_Path{k} ds_Name{k} ds_EXT{k} chan_names{k} chan_pos{k};
            end
                       
            % load saved head model - updates sphereList and sets flag for singe or multi
            loadHeadModelFile(hdm_File);
            updateDisplay;

            msgbox('Multiple Fitsphere is done!');
            
        end
    end

    function display_optCallback(~,~)   
        opts.pt_size = pt_size;
        opts.tail_len = tail_len;
        opts.tail_width = tail_width;
        opts.tail_show = tail_show;
        opts.showAllPoints = showAllPoints;
        
        opts = display_options(opts); 

        pt_size = opts.pt_size;
        tail_len = opts.tail_len;
        tail_width = opts.tail_width;
        tail_show = opts.tail_show;
        showAllPoints = opts.showAllPoints;

        updateDisplay;

    end

    function opts = display_options(opts)
        
        save_opts = opts;
        
        scrsz=get(0,'ScreenSize');
        f2=figure('Name', 'Display options', 'Position', [(scrsz(3)-500)/2 (scrsz(4)-250)/2 500 250],...
            'menubar','none','numbertitle','off', 'color','white');
        
        uicontrol('style','text','units','normalized','position',[0.08 0.66 0.45 0.2],'horizontalalignment','left',...
            'string','Marker size (pixels): ','fontsize',10,'backgroundColor','white','FontWeight','normal');
        
        uicontrol('style','edit','units','normalized','position',...
            [0.47 0.75 0.1 0.12],'String', opts.pt_size,...
            'FontSize', 10,'backgroundColor','white','callback',@pt_value_callback);
        
        function pt_value_callback(src, ~)
            opts.pt_size = str2double(get(src,'string'));
        end
        
        tail_length_text = uicontrol('style','text','units','normalized','position',[0.08 0.5 0.45 0.2],'horizontalalignment','left',...
            'string','Marker tail length (pixels): ','fontsize',10,'backgroundColor','white','FontWeight','normal');
        
        tail_length_value = uicontrol('style','edit','units','normalized','position',...
            [0.47 0.61 0.1 0.12],'String', opts.tail_len,...
            'FontSize', 10,'backgroundColor','white', 'callback',@tail_len_callback);
        
        function tail_len_callback(src, ~)
            opts.tail_len = str2double(get(src,'string'));
        end
        
        tail_width_text = uicontrol('style','text','units','normalized','position',[0.08 0.35 0.45 0.2],'horizontalalignment','left',...
            'string','Marker tail width (pixels): ','fontsize',12,'backgroundColor','white','FontWeight','normal');
        
        tail_width_value = uicontrol('style','edit','units','normalized','position',...
            [0.47 0.46 0.1 0.12],'String', opts.tail_width,...
            'FontSize', 10,'backgroundColor','white','callback',@tail_wid_callback);
        
        function tail_wid_callback(src, ~)
            opts.tail_width = str2double(get(src,'string'));
        end

        if opts.tail_show
            set(tail_length_text,'enable','on');
            set(tail_length_value,'enable','on');
            set(tail_width_text,'enable','on');
            set(tail_width_value,'enable','on');
        else
            set(tail_length_text,'enable','off');
            set(tail_length_value,'enable','off');
            set(tail_width_text,'enable','off');
            set(tail_width_value,'enable','off');
        end       
    
        uicontrol('style','checkbox','units', 'normalized',...
            'position',[0.65 0.74 0.3 0.15],'String','show all Markers',...
            'FontSize', 10,'backgroundColor','white','Value',opts.showAllPoints,...
            'callback',@showAll_Callback);           
        function showAll_Callback(src, ~)
            opts.showAllPoints = get(src,'Value');
        end

        uicontrol('style','checkbox','units', 'normalized',...
            'position',[0.65 0.6 0.3 0.15],'String','show tail (normals)',...
            'FontSize', 10,'backgroundColor','white','Value',opts.tail_show,...
            'callback',@tail_show_Callback);
        
        function tail_show_Callback(src, ~)
            opts.tail_show = get(src,'Value');
            if opts.tail_show
                set(tail_length_text,'enable','on');
                set(tail_length_value,'enable','on');
                set(tail_width_text,'enable','on');
                set(tail_width_value,'enable','on');
            else
                set(tail_length_text,'enable','off');
                set(tail_length_value,'enable','off');
                set(tail_width_text,'enable','off');
                set(tail_width_value,'enable','off');
            end
            
        end   
        
        uicontrol('Units','Normalized','Position',[0.6 0.05 0.12 0.12],'String','OK',...
            'FontSize',10,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@save_callback);
          
        uicontrol('Units','Normalized','Position',[0.8 0.05 0.12 0.12],'String','Cancel',...
            'FontSize',10,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@cancel_callback);
       
            function save_callback(~, ~) 
                uiresume(f2);        
                close(f2); 
            end

            function cancel_callback(~, ~)
                opts = save_opts;
                uiresume(f2);        
                close(f2); 
            end
        
        uiwait(f2);
        
    end

    contrastSlider = uicontrol('style','slider','units', 'normalized',...
        'position',[0.05 0.61 0.025 0.28],'min',0.0,'max',maxBrightness,...
        'Value',contrast_value, 'sliderStep', [0.03 0.1],'BackGroundColor',[0.9 0.91 0.9],'callback',@contrast_slider_Callback);

    if ~ismac
        set(contrastSlider, 'position',[0.05 0.62 0.03 0.27]);
    end

    uicontrol('style','text','units','normalized','position',[0.05 0.9 0.05 0.02],...
        'string','Max','fontsize',9,'FontWeight','normal','background','white', 'horizontalalignment','left');

    uicontrol('style','text','units','normalized','position',[0.05 0.58 0.05 0.02],...
        'string','Min','fontsize',9,'FontWeight','normal','background','white','horizontalalignment','left');

    uicontrol('style','text','units','normalized','position',[0.05 0.56 0.08 0.02],...
        'string','Brightness','fontsize',9,'FontWeight','normal','background','white','horizontalalignment','left');

    function contrast_slider_Callback(src, ~)
        contrast_value = get(src,'value');
        updateDisplay;
    end

    function M = bw_getTransformMatrix(nasion_pos, left_preauricular_pos, right_preauricular_pos )
        
        % build CTF coordinate system
        % origin is midpoint between ears
        origin=(left_preauricular_pos + right_preauricular_pos)/2;
        
        % x axis is vector from this origin to Nasion
        x_axis= nasion_pos - origin;
        x_axis=x_axis/sqrt(dot(x_axis,x_axis));
        
        % y axis is origin to left ear vector
        y_axis=[left_preauricular_pos - origin];
        y_axis=y_axis/sqrt(dot(y_axis,y_axis));
        
        % This y-axis is not necessarely perpendicular to the x-axis, this corrects
        z_axis=cross(x_axis,y_axis);
        y_axis=cross(z_axis,x_axis);        
        
        % now build 4 x 4 affine transformation matrix
        
        rmat = [ [x_axis 0]; [y_axis 0]; [z_axis 0]; [0 0 0 1] ]';
        
        % translation matrix + origin
        tmat = diag([1 1 1 1]);
        tmat(:,4) = [origin, 1];
        M = tmat * rmat;
    end
       
    function mesh = create_surface_mesh( surface_points )
        
        s = sprintf('Tesselating surface (%d vertices)...', size(surface_points,1));
        wbh = waitbar(0.4,s);
        
        mesh.faces = MyCrustOpen(surface_points);        % better triangulation!
        mesh.vertices = surface_points;

        delete(wbh);       
                
    end
                   
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % % separate display to load and fit surfaces 
    % %
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   
    function viewSurface( surface )

        df = figure('Name', 'MRI Surface', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 700 600],...
                'menubar','none','numbertitle','off', 'Color','white');
        FILE_MENU = uimenu('label','File');
        uimenu(FILE_MENU,'label','Load Head Surface...','enable','on','callback',@loadSurfaceCallback);
        HEADSHAPE__MENU = uimenu(FILE_MENU,'label','Load Headshape...');
        uimenu(HEADSHAPE__MENU,'label','CTF/Brainstorm Polhemus File (*.pos)','enable','on','callback',@loadPolhemusCallback);
        uimenu(HEADSHAPE__MENU,'label','Brainstorm Channel file (*.mat)','enable','on','callback',@loadChannelCallback);
        uimenu(HEADSHAPE__MENU,'label','MEG Sensor Overlay (*.ds)','enable','on','callback',@loadSensorsCallback);
        % uimenu(HEADSHAPE__MENU,'label','Surface point file (*.sfp)','enable','on','callback',@loadSFPCallback);
        
        uimenu(FILE_MENU,'label','Load Surface mesh...','separator','on','enable','on','callback',@loadSurfaceMeshCallback);
        uimenu(FILE_MENU,'label','Save Surface mesh ...','callback',@save_vtkCallback);
         
        uimenu(FILE_MENU,'label','Close','Callback','closereq','Accelerator','W','separator','on');    
        
        functionName = 'enableLegacyExplorationModes';
        if exist(functionName)
            enableLegacyExplorationModes(df);
        end

        [~,n,e] = fileparts(mriName);
        s = sprintf('MRI Surface (%s)',[n e]);
        set(df,'Name',s);
    
        if ~exist('surface', 'var')
            surface = [];
        end
        
        mesh = [];      % overlay mesh
        shapeFile = [];

        % create a legend for markers
        legendbox = [0.35 0.045 0.3 0.08];           
        subplot('Position', legendbox);    
        
        ax = gca;
        hold on
        cols = [ 0 0 1; 0 1 0; 1 0 0 ];
        temp = [0.1 1; 0.1 0.5; 0.1 0];
        scatter(ax, temp(:,1),temp(:,2),150, cols,'filled');  
        uicontrol(df, 'style','text','units', 'normalized','String','Nasion','position',[0.4 0.11 0.08 0.03],...
            'fontsize',12,'ForegroundColor','blue','BackgroundColor','white','HorizontalAlignment','left');
        uicontrol(df, 'style','text','units', 'normalized','String','LPA','position',[0.4 0.07 0.08 0.03],...
            'fontsize',12,'ForegroundColor','green','BackgroundColor','white','HorizontalAlignment','left');
        uicontrol(df, 'style','text','units', 'normalized','String','RPA','position',[0.4 0.03 0.08 0.03],...
            'fontsize',12,'ForegroundColor','red','BackgroundColor','white','HorizontalAlignment','left');
        temp = [0.5 1; 0.5 0.5; 0.5 0];
        scatter(ax, temp(:,1),temp(:,2),200, cols,'o','LineWidth',2);     
        uicontrol(df, 'style','text','units', 'normalized','String','Overlay Nasion','position',[0.52 0.11 0.12 0.03],...
            'fontsize',12,'ForegroundColor','blue','BackgroundColor','white','HorizontalAlignment','left');
        uicontrol(df, 'style','text','units', 'normalized','String','Overlay LPA','position',[0.52 0.07 0.12 0.03],...
            'fontsize',12,'ForegroundColor','green','BackgroundColor','white','HorizontalAlignment','left');
        uicontrol(df, 'style','text','units', 'normalized','String','Overlay RPA','position',[0.52 0.03 0.12 0.03],...
            'fontsize',12,'ForegroundColor','red','BackgroundColor','white','HorizontalAlignment','left');
        xlim([0 1])
        ylim([0 1])
        axis off;
        hold off;

        % create surface view

        headbox = [0.25 0.15 0.8 0.8];           
        subplot('Position', headbox);    
        
        axis('equal');
        view([-130 20]);
        axis off;

        % update lighting during rotate
        lh = [];
        h = rotate3d;
        h.Enable = 'on';
        h.ActionPostCallback = @updateLight;
            function updateLight(~,~)
                delete(lh)
                lh = camlight('headlight');
            end

        % suppress El/Az readout
        h.ActionPreCallback = @rotate3d_ActionPreCallback; 
        function rotate3d_ActionPreCallback(v,~,~)
            hm = uigetmodemanager(v);
            hm.CurrentMode.ModeStateData.textBoxText.Visible = 'off';
        end    

        hold on;
        ax = gca;

        MRI_alpha = 0.8;
        OVERLAY_alpha = 1.0;

        % draw fids before creating patch for legend

        tfids = [na_RAS; le_RAS; re_RAS];
        initial_fids = tfids;

        cols = [ 0 0 1; 0 1 0; 1 0 0 ];
        fidH = scatter3(ax, tfids(:,1),tfids(:,2),tfids(:,3),200, cols,'filled');     
        set(fidH,'visible','off');
        
        polColor = [0 0.5 0.5];
        % create pfid handle - then hide
        pfids = [0 0 0; 0 0 0; 0 0 0];
        pfidH = scatter3(ax, pfids(:,1),pfids(:,2),pfids(:,3),350, cols,'o','LineWidth',3);
        set(pfidH,'visible','off');
        
        ph = patch('Vertices',[],'Faces',[]);  
        ph.Clipping = 'off';

        shading flat
        lighting flat;      % gouraud not good if surface is not smooth?
        material dull;

        % Matlab hidden feature ....
        H = uitoolbar('parent',df);
        uitoolfactory(H,'Exploration.ZoomIn');
        uitoolfactory(H,'Exploration.ZoomOut');
        uitoolfactory(H,'Exploration.Pan');
        uitoolfactory(H,'Exploration.DataCursor');
        uitoolfactory(H,'Exploration.Rotate');        

        cursorH = datacursormode(df);   
        set(cursorH,'enable','on','UpdateFcn',@UpdateCursors);
        cursorH.removeAllDataCursors;
        cursorH.enable = 'on';
        axis off 



        if ~isempty(surface)
            updateSurface;
        end

        pfids = [];

        polH = [];                  % force redraw since number of points may change each time
        offset = 0.0;

        hold off
        axis off 

        annotation('rectangle',[0.01 0.53 0.28 0.45],'Color','blue');
        uicontrol('style','text','units','normalized','foregroundColor','blue',...
        'position',[0.08 0.945 0.1 0.05],'String','Fiducials','BackgroundColor','white','FontSize',11,'FontWeight','bold');

        surfaceFile_txt = uicontrol('style','text','units','normalized','HorizontalAlignment','left',...
            'position',[0.3 0.94 0.7 0.05],'String','Surface File: none','BackgroundColor','white','FontSize',11);

        % set fiducials
        uicontrol(df, 'style','pushbutton','units','normalized','Position',...
            [0.04 0.9 0.12 0.035],'String','Set Nasion','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','blue','callback',@set_nas_callback);

        function set_nas_callback(~,~)
            s = getCursorInfo(cursorH);
            tfids(1,:) = s.Position;
            fids_changed = 1;
            set(REVERT_BUTTON,'enable','on');
            set(fidH,'XData',tfids(:,1), 'YData',tfids(:,2), 'ZData',tfids(:,3))         
        end
        uicontrol(df, 'style','pushbutton','units','normalized','Position',...
            [0.04 0.84 0.12 0.035],'String','Set LPA','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','green','callback',@set_le_callback);
        function set_le_callback(~,~)
            s = getCursorInfo(cursorH);
            tfids(2,:) = s.Position;
            fids_changed = 1;
            set(REVERT_BUTTON,'enable','on');
            set(fidH,'XData',tfids(:,1), 'YData',tfids(:,2), 'ZData',tfids(:,3))         
        end        
        uicontrol(df, 'style','pushbutton','units','normalized','Position',...
            [0.04 0.78 0.12 0.04],'String','Set RPA','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_re_callback);
        function set_re_callback(~,~)
            s = getCursorInfo(cursorH);
            tfids(3,:) = s.Position;
            fids_changed = 1;
            set(REVERT_BUTTON,'enable','on');
            set(fidH,'XData',tfids(:,1), 'YData',tfids(:,2), 'ZData',tfids(:,3))         
        end               
    
        UPDATE_FIDS_BUTTON = uicontrol(df, 'style','pushbutton','units','normalized','Position',...
            [0.04 0.7 0.16 0.04],'String','Set To Overlay','BackgroundColor','white','enable','off',...
            'FontSize',9,'ForegroundColor','black','callback',@update_fids_callback);      
            function update_fids_callback(~,~)   
                r = questdlg('Set MRI fiducials to the current overlay fiducials?','Save Fiducials','Yes','Cancel','Cancel');
                if strcmp(r,'Yes')
                    tfids = round(pfids);
                    set(fidH, 'XData',tfids(:,1),'YData',tfids(:,2),'ZData',tfids(:,3));  
                    set(REVERT_BUTTON,'enable','on');
                end
            end

        uicontrol(df, 'style','pushbutton','units','normalized','Position',...
            [0.04 0.62 0.16 0.04],'String','Apply Changes','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','black','callback',@apply_changes_callback);      

        function apply_changes_callback(~,~)
            % set MRI fiducials to current             
            r = questdlg('Set the MRI fiducials to the current fiducials?','Save Fiducials','Yes','No','No');
            if strcmp(r,'No')
                return;
            end
           
            % makes sure to round in case of high-res mesh in floating
            % point
            na_RAS = round(tfids(1,:));
            le_RAS = round(tfids(2,:));
            re_RAS = round(tfids(3,:));
            updateFidText;       % update text fields in main window;
            fids_changed = 1;
            set(REVERT_BUTTON,'enable','on');
            [~,name] = fileparts(mriName);
            s = sprintf('The MRI fiducials have been set to new values. Use Save Fiducials to overwrite values in %s.mat file.',name);
            warndlg(s)

        end

               
        REVERT_BUTTON = uicontrol(df, 'style','pushbutton','units','normalized','Position',...
            [0.04 0.56 0.16 0.04],'String','Undo Changes','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','black','callback',@revert_callback);      

        function revert_callback(~,~)
            % set MRI fiducials to current             
            r = questdlg('Undo Changes','Save Fiducials','Yes','No','Cancel');
            if strcmp(r,'No')
                return;
            end
            tfids = initial_fids;
            na_RAS = tfids(1,:);
            le_RAS = tfids(2,:);
            re_RAS = tfids(3,:);
            updateFidText;       % update text fields in main window;
            fids_changed = 0;
            set(REVERT_BUTTON,'enable','off');
                   
            set(fidH, 'XData',tfids(:,1),'YData',tfids(:,2),'ZData',tfids(:,3)); 

        end

        TRANSP_SLIDER_TEXT = uicontrol(df, 'style','text','units', 'normalized',...
            'position',[0.04 0.08 0.15 0.03],'String','MRI Opacity',...
            'FontSize',10,'HorizontalAlignment','left','BackGroundColor', 'white','enable','on');         
        TRANSP_SLIDER = uicontrol(df, 'style','slider','units', 'normalized',...
            'position',[0.04 0.04 0.24 0.03],'min',0,'max',1.0,...
            'Value',MRI_alpha, 'sliderStep', [0.01 0.1],'BackGroundColor','white','enable','on','callback',@transparency_slider_Callback);        
        function transparency_slider_Callback(src,~)    
            MRI_alpha = get(src,'value');
            set(ph,'faceAlpha',MRI_alpha);
        end
           
        fids_changed = 0;
        set(REVERT_BUTTON,'enable','off');

        updateLight

        function [newText, position] = UpdateCursors(src,evt)
            position = get(evt,'Position');
            set(src,'MarkerSize',6,'FontSize',9);
            s = sprintf('%.2f %.2f %.2f',position);
            newText = s;            
        end

        function updateSurface         
            set(ph, 'Vertices',surface.vertices,'Faces',surface.faces,...
                'FaceColor','flat','EdgeColor','none','FaceAlpha',MRI_alpha);
            faceColor = [0.8 0.75 0.75];
            fvc = repmat(faceColor,size(surface.vertices,1),1);
            set(ph,'FaceVertexCData',fvc);
            set(fidH,'visible','on');
            updateLight

        end

        function loadSurfaceCallback(~,~)
                 
            [meshfilename, meshfilepath, ~] = uigetfile({'*head_surface', 'Freesurfer Head Surface'},...
                'Select a FreeSurfer Surface');
            meshFile = fullfile(meshfilepath, meshfilename);
            if meshfilename == 0
                return;
            end

            [~, surface] = bw_readMeshFile(meshFile);
           
            % want meshes in voxel (MRI) relative coordinates
            
            % ** for freesurfer meshes we have to scale mesh back to RAS voxels (native) space
            % ** have to scale then translate origin which is center of image...
    
            fprintf('rescaling mesh from mm to voxels (scale = %g mm/voxel)\n', mmPerVoxel);
                   
            surface.vertices = surface.vertices ./ mmPerVoxel;
            % translate origin to correspond to original RAS volume
            % adding 129 instead of 128 seems to make MNI coords line up on midline better
            % both on .nii and for Talairach coordinates. Also corresponds to
            % conversion shown in surfaceRAS to Talairach conversion documentation                   
            surface.vertices = surface.vertices + 129;
            surface.faces = surface.faces + 1;
            updateSurface;   

            [~,n,e] = fileparts(meshFile);
            s = sprintf('Surface File: %s',[n e]);
            set(surfaceFile_txt,'string',s);
                     
        end     

        function loadSurfaceMeshCallback(~,~)
                
            [meshfilename, meshfilepath, ~] = uigetfile({'*.vtk', 'VTK Surface Mesh'},...
                'Select a Mesh File');
            meshFile = fullfile(meshfilepath, meshfilename);
            if meshfilename == 0
                return;
            end

            [~, surface] = bw_readMeshFile(meshFile);

            surface.faces = surface.faces + 1;  % indices start at 1 ....                     
            updateSurface;   

            [~,n,e] = fileparts(meshFile);
            s = sprintf('Surface File: %s',[n e]);
            set(surfaceFile_txt,'string',s);
                     
        end    
        %%%%%%%%%%%%%%%%%%
        % Polhemus Overlay 
        %%%%%%%%%%%%%%%%%%%
    
        function loadPolhemusCallback(~,~)
           [shapeFile, shapePath, ~] = uigetfile(...
                {'*.pos','CTF (Brainstorm) Polhemus file (*.pos)'},...
                'Select a head shape file');
            if shapeFile == 0
                return;
            end
            shapeFile = [shapePath shapeFile];
            loadShapeOverlay;
        end
        
        function loadSensorsCallback(~,~)
           [dsName, dsPath, ~] = uigetfile(...
                {'*.ds','CTF dataset (*.ds)'},...
                'Select a Dataset file');
            if dsName == 0
                return;
            end
            shapeFile = fullfile(dsPath,dsName); % uses sensor positions
            loadShapeOverlay;
        end

        function loadChannelCallback(~,~)
           [shapeFile, shapePath, ~] = uigetfile(...
                {'*.mat','Brainstorm channel file (*.mat)'},...
                'Select a head shape file');
            if shapeFile == 0
                return;
            end
            shapeFile = [shapePath shapeFile];
            loadShapeOverlay;

        end
        
        function loadShapeOverlay
            
            [~,n,e] = fileparts(shapeFile);
            fname = [n e];
            s = sprintf('%s', fname);
            set(SHAPE_FILE_TXT, 'string',s,'enable','on');

            loadPoints;
            drawPoints;

            % get initial fit error
            meanDistance = getFitError(surface.vertices', mesh.vertices);

            % meanDistance = mean(totalDistances) * mmPerVoxel;    
            fprintf('Mean distance of overlay to surface (fit error) = %.2f mm  ** initial **\n', meanDistance);
            s  = sprintf('Fit Error = %.2f mm', meanDistance);
            set(FIT_ERROR_TEXT,'string',s);


            set(FIT_SURFACE_BUTTON,'enable','on');
            set(UPDATE_FIDS_BUTTON,'enable','on');
            set(OFFSET_EDIT,'enable','on');
            set(OFFSET_EDIT_TXT,'enable','on');
            set(OFFSET_EDIT_TXT2,'enable','on');

            set(MESH_SLIDER_TEXT,'enable','on');
            set(MESH_SLIDER,'enable','on');            
            set(TRANSP_SLIDER_TEXT,'enable','on');
            set(TRANSP_SLIDER,'enable','on');    
        end

        function loadPoints

            if ~exist(shapeFile,'file')
               return;
            end
           
            [~,~,ext] = fileparts(shapeFile);
            
            if strcmp(ext,'.ds')
                % read in sensor positions (e.g., for OPM sensor fit ...)
                [headshape, orientations] = bw_getSensorCoordinates(shapeFile);
                % convert to mm
                headshape = headshape * 10.0;
                % get true fiducials
                [fids_head, ~] = bw_readHeadCoilFile(shapeFile);
                % check if no hc file use defaults
                if isempty(fids_head)
                    fprintf('No head coil file. Using default fiducials\n');
                    na = [80 0 0];
                    le = [0 80 0];
                    re = [0 -80 0];
                else
                    na = fids_head.na * 10.0;
                    le = fids_head.le * 10.0;
                    re = fids_head.re * 10.0;
                end
                if offset ~= 0.0
                    fprintf('Scaling sensor locations along their axes by %.2f mm\n', offset)
                    for k=1:size(headshape,1)                           
                        pos = headshape(k,1:3);
                        ori = orientations(k,1:3);
                        pos = pos + (ori * -offset);
                        headshape(k,1:3) = pos;
                    end
                end
            else
                % else read point clouds without orientation vectors
                if strcmp(ext,'.pos')
                    [headshape, na, le, re] = bw_readPolhemusFile(shapeFile);
                    % these routines now return shape data unscaled (in cm)
                    headshape = headshape * 10.0;
                    na = na * 10.0;
                    le = le * 10.0;
                    re = re * 10.0;
                elseif strcmp(ext,'.sfp')
                    [headshape, na, le, re] = bw_readSFPFile(shapeFile);
                    headshape = headshape * 10.0;
                    na = na * 10.0;
                    le = le * 10.0;
                    re = re * 10.0;
                elseif strcmp(ext,'.mat')
                    [headshape, na, le, re] = bw_readChannelFile(shapeFile);
                    headshape = headshape * 10.0;
                    na = na * 10.0;
                    le = le * 10.0;
                    re = re * 10.0;
                end
                % expand / contract by offset - change to use centroid? 
                if offset ~= 0.0
                    fprintf('Scaling head shape points towards origin by %.2f mm\n', offset)
                    na = na + (na / norm(na) * offset);
                    le = le + (le / norm(le) * offset);
                    re = re + (re / norm(re) * offset);
    
                    for k=1:size(headshape,1)
                        p = headshape(k,1:3);
                        p = p + (p / norm(p) * offset); 
                        headshape(k,1:3) = p;
                    end
                end
            end

            % % mesh vertices are in in head coordinates.  
            % % convert to mri voxels in RAS

            [~, mesh.vertices] = Head_to_Voxels(headshape);
            [~, pfids] = Head_to_Voxels([na; le; re]);   

        end

        function drawPoints

            if isempty(mesh.vertices)
                return;
            end

            hold on;
            if ~isempty(pfidH)
                set(pfidH,'XData',pfids(:,1),'YData',pfids(:,2),'ZData',pfids(:,3)); 
                set(pfidH,'visible','on');
            end

           pts = mesh.vertices;
           if isempty(polH)
                polH = scatter3(ax, pts(:,1),pts(:,2),pts(:,3),30,polColor,'filled');    
                set(polH,'visible','on');
            else
                set(polH, 'XData',pts(:,1),'YData',pts(:,2),'ZData',pts(:,3));                   
            end
            
            hold off

        end

        annotation('rectangle',[0.01 0.15 0.28 0.35],'Color','blue');
        uicontrol('style','text','units','normalized','foregroundColor','blue',...
        'position',[0.08 0.485 0.1 0.03],'String','Shape Overlay','BackgroundColor','white','FontSize',11,'FontWeight','bold');

 
        SHAPE_FILE_TXT = uicontrol(df, 'style','text','units', 'normalized',...
            'position',[0.04 0.42 0.23 0.06],'String','File:','enable','off',...
            'FontSize',10,'HorizontalAlignment','left','BackGroundColor', 'white');         
        OFFSET_EDIT_TXT = uicontrol(df, 'style','text','units', 'normalized',...
            'position',[0.04 0.37 0.20 0.03],'String','Expand/Contract by:','enable','off',...
            'FontSize',10,'HorizontalAlignment','left','BackGroundColor', 'white');         
        OFFSET_EDIT_TXT2 = uicontrol(df, 'style','text','units', 'normalized',...
            'position',[0.1 0.32 0.04 0.03],'String','mm','enable','off',...
            'FontSize',10,'HorizontalAlignment','left','BackGroundColor', 'white');         
        OFFSET_EDIT = uicontrol(df, 'style','edit','units','normalized','Position',...
            [0.04 0.32 0.05 0.04],'String',offset,'BackgroundColor','white','enable','off',...
            'FontSize',10,'ForegroundColor','black','callback',@offset_edit_callback);      
            function offset_edit_callback(src,~)    
                s = get(src,'string');
                offset = str2double(s);

                % reread original and apply scaling
                loadPoints;
                drawPoints;
                         
                meanDistance = getFitError(surface.vertices', mesh.vertices);
                s  = sprintf('Fit Error = %.2f mm', meanDistance);
                set(FIT_ERROR_TEXT,'string',s);

            end

        FIT_SURFACE_BUTTON = uicontrol(df, 'style','pushbutton','units','normalized','Position',...
            [0.04 0.24 0.2 0.04],'String','Fit Overlay to Surface','BackgroundColor','white','enable','off',...
            'FontSize',9,'ForegroundColor','black','callback',@fit_surfaces_callback);      

        MESH_SLIDER_TEXT = uicontrol(df, 'style','text','units', 'normalized',...
            'position',[0.04 0.2 0.2 0.03],'String','Overlay Opacity',...
            'FontSize',10,'HorizontalAlignment','left','BackGroundColor', 'white','enable','off');         
        MESH_SLIDER = uicontrol(df, 'style','slider','units', 'normalized',...
            'position',[0.04 0.16 0.2 0.03],'min',0,'max',1.0,'enable','off',...
            'Value',1.0, 'sliderStep', [0.01 0.1],'BackGroundColor','white','callback',@overlay_slider_Callback);        
            function overlay_slider_Callback(src,~)    
                OVERLAY_alpha = get(src,'value');
                set(polH,'MarkerFaceAlpha',OVERLAY_alpha);
                set(polH,'MarkerEdgeAlpha',OVERLAY_alpha);
                
            end

        FIT_ERROR_TEXT = uicontrol(df, 'style','text','units', 'normalized',...
            'position',[0.4 0.15 0.3 0.03],'String','','BackGroundColor','white','FontWeight','bold',...
            'FontSize',14,'HorizontalAlignment','left','ForeGroundColor','red','enable','on');         



        function fit_surfaces_callback(~,~)

            if isempty(mesh.vertices)
                return;
            end


            % defaults
            outlierThreshold = 10.0;
            scaleFlag = 0;

            input = inputdlg({'Threshold for removing outliers (distance from MRI surface in mm):';'Allow Affine scaling? (1 = yes, 0 = no)'},...
                'Fit Surface using ICP', [1 100; 1 100], {num2str(outlierThreshold), num2str(scaleFlag)} );
            if isempty(input)
                return;                
            end
            outlierThreshold = str2double(input{1});
            scaleFlag = round( str2double(input{2}));

            % if surface only use face points for error calculation / fitting

            pts = mesh.vertices;
           
            fprintf('Fitting overlay mesh (%d vertices) to MRI surface (%d vertices) using ICP...\n',...
                size(pts,1),size(surface.vertices,1));
            if scaleFlag == 1
                fprintf('Affine scaling = ON\n');
            else
                fprintf('Affine scaling = OFF\n');                
            end

            wbh = waitbar(0,'Fitting overlay mesh to MRI surface using ICP...');
            waitbar(0.0,wbh);

            fprintf('Computing initial error...\n');                

            tic;      

            waitbar(0.1,wbh,'Computing initial error...');

            meanDistance = getFitError(surface.vertices', mesh.vertices);

            fprintf('Mean distance of overlay to surface (fit error) = %.2f mm  ** initial **\n', meanDistance);

            waitbar(0.3,wbh,'Fitting surface points using ICP (iteration 1)...');     

            fid2 = tfids; % doesn't matter which reference is passed?

            % Pass MRI surface as data1 to this routine since delaunay triangulation
            %  is applied to this surface and doesn't like duplicate points. 
            M = spm_eeg_inv_icp(surface.vertices', pts(:,1:3)', fid2', fid2',[],[], scaleFlag); 

            % rotate *all* mesh vertices for surfaces
            vertices = [mesh.vertices ones(size(mesh.vertices,1),1)];
            mesh.vertices = vertices * M';
            mesh.vertices(:,4) = [];  

            % display rotated mesh 

            set(polH, 'XData',pts(:,1),'YData',pts(:,2),'ZData',pts(:,3));   
            set(polH,'visible','on');
            

            % rotate and display polhemus fids
            if ~isempty(pfids) 
               pfids_rot = [pfids ones(3,1)];
               pfids = pfids_rot * M';
               pfids(:,4) = [];
               set(pfidH, 'XData',pfids(:,1),'YData',pfids(:,2),'ZData',pfids(:,3));   
               set(pfidH,'visible','on');
            end     

            drawnow;


            % if surface only use face points for error calculation / fitting
            pts = mesh.vertices;              

            waitbar(0.5,wbh,'Calculating fit error...checking for outliers');
            fprintf('Checking for outliers  > %.1f mm ...\n', outlierThreshold);

            % remove outliers     
            bidx = [];
            thresh = outlierThreshold / mmPerVoxel;    % threshold in voxels  
            for k=1:size(pts,1)
                % get closest surface point 
                distances = vecnorm(surface.vertices' - repmat(pts(k,1:3), size(surface.vertices,1),1)' );
                mindist = min(distances);
                if mindist > thresh
                    bidx(end+1) = k;
                end
                totalDistances(k) = mindist;
            end
            numOutliers = length(bidx);

            meanDistance = mean(totalDistances);       
            fprintf('Mean distance of overlay to surface (fit error) = %.2f mm ** after iteration 1 ** \n', meanDistance * mmPerVoxel);

            % if found outliers remove them and redo the fit.

            fprintf('Removing %d outliers ...\n', numOutliers);
            if ~isempty(bidx)
                pts(bidx,:) = [];
            end          

            waitbar(0.7,wbh,'Fitting surface points using ICP (iteration 2)...');     

            % ** always do 2 iterations ... 
            fprintf('Re-fitting head shape with outliers removed ...(iteration 2)\n');       
            M = spm_eeg_inv_icp(surface.vertices', pts(:,1:3)', fid2', fid2',[],[], scaleFlag); 

            % rotate *all* mesh vertices for display
            vertices = [mesh.vertices ones(size(mesh.vertices,1),1)];
            mesh.vertices = vertices * M';
            mesh.vertices(:,4) = [];

            set(polH, 'XData',pts(:,1),'YData',pts(:,2),'ZData',pts(:,3));   
            set(polH,'visible','on');
            

            % rotate polhemus fids
            if ~isempty(pfids) 
               pfids_rot = [pfids ones(3,1)];
               pfids = pfids_rot * M';
               pfids(:,4) = [];
               set(pfidH, 'XData',pfids(:,1),'YData',pfids(:,2),'ZData',pfids(:,3)); 
            end     

            fprintf('Computing final error...\n');                
            waitbar(0.9,wbh,'Calculating fit error...');     

            % get final fit error
            % only use face points for error calculation / fitting
            
            meanDistance = getFitError(surface.vertices', mesh.vertices);

            fprintf('Mean distance of polhemus points to surface (fit error) = %.2f mm  ** after iteration 2 **\n', meanDistance);      
            fprintf('... done.\n');                
            s  = sprintf('Fit Error = %.2f mm', meanDistance);
            set(FIT_ERROR_TEXT,'string',s);

            toc
            delete(wbh);

        end

        function save_vtkCallback( ~,~ )

                if isempty(surface.vertices)
                    warndlg('No surface points to save');
                    return;            
                end
                saveName = strrep(mriName,'.mri','.vtk');

                [filename, pathname, ~] = uiputfile( ...
                    {'*.vtk','VTK mesh file (*.vtk)'}, ...
                    'Save surface as mesh file',saveName);

                if isequal(filename,0) || isequal(pathname,0)
                    return;
                end

                fullname = fullfile(pathname,filename);

                answer = questdlg('Save in Voxel Coordinates or Head Coordinates?',...
                    'Save Surface','Voxel coordinates','Head Coordinates','Head Coordinates');
                if strcmp(answer,'Head Coordinates')
                    vox2ctf = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS, mmPerVoxel * 0.1);
                    vertices = [surface.vertices ones(size(surface.vertices,1),1)] * vox2ctf;          
                    vertices(:,4) = [];
                else
                    vertices = surface.vertices;
                end
                bw_save_surface_vtk(vertices, surface.faces, fullname);
        end

        function meanDistance = getFitError(surfacePts, headPts)
    
            totalDistances = [];
            for k=1:size(headPts,1)
                distances = vecnorm(surfacePts - repmat( headPts(k,1:3), size(surfacePts,2),1)' );
                mindist = min(distances);
                totalDistances(k) = mindist;
            end
            meanDistance = mean(totalDistances) * mmPerVoxel;
        end
   end

    % load pass files now...
    
    if exist('mriFile','var')
        openMRI(mriFile);
    end

    if exist('overlayFile','var') 
        if ~iscellstr(overlayFile)   
            [~,~,e] = fileparts(char(overlayFile));     
            if strcmp(e,'.dip')
                Dip_File = overlayFile;
                loadDipoleFile(Dip_File);
            end  
        else        
            % get extension of first file
            filename = char( overlayFile(1) );            
            [~,~,e] = fileparts(filename);     
            if strcmp(e,'.svl')
                loadOverlays(overlayFile);
            else
                loadMNIOverlays(overlayFile);
            end
        end
    end


end
