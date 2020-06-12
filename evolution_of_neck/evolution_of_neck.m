%% 
% An image processing script to determine the evolution of neck radius 
% during coalescence of two bubbles or droplets. The script requires 
% tifflib library. Sample and background images can be found inside the folder.
% Created by: Haryo Mirsandi

addpath('../tifflib/')
close all;
clearvars;

%% read background image
disp('choose the background image');
[file_name, file_path] = uigetfile('.tif');
cd(file_path);
image_background = imread(file_name);
image_background = double(image_background);

%% read the image series
disp('choose the image series');
[file_name, file_path] = uigetfile('.tif');
% get image information
image.info = imfinfo(file_name);
image.width = image.info.Width;
image.height = image.info.Height;
image.length = length(image.info);
image.allframe = zeros(image.height,image.width,image.length,'uint16');
image.info = [];
% parameters related to the image series, etc.
image.center_x = 288;       % location of the center of coalescence defined 
image.center_y = 370;       % from the original image (use imagej)
image.delta = 10;           % width from the center in the x direction
image.res = 1.5984e-2;      % mm/pixel (use imagej)
image.dt = 0.1;             % ms
image.start = 1;
image.threshold = 2;        % threshold for binarization. 1.5 is usually OK
                            % 0.8 for images from paraview

%% store the images in allframe
file_id = tifflib('open',file_name,'r');
rows_per_strip = tifflib('getField',file_id,Tiff.TagID.RowsPerStrip);
for num=1:image.length  
    tifflib('setDirectory',file_id,num-1);
    % go through each strip of image
    rows_per_strip = min(rows_per_strip,image.height);
    for row = 1:rows_per_strip:image.height
        row_idx = row:min(image.height,row+rows_per_strip-1);
        strip_num = tifflib('computeStrip',file_id,row);
        image.allframe(row_idx,:,num) = ...
        tifflib('readEncodedStrip',file_id,strip_num-1);
    end
end
tifflib('close',file_id);

%% determine the evolution of the neck formation
neck_length = zeros(1,image.length);
for num = image.start:image.length
    % get the current frame and perform binarization
    current_image = double(image.allframe(:,:,num));
    current_image = image_background./current_image;
    current_image_bw = imbinarize(current_image,image.threshold) ;
    % get the boundaries
    B = bwboundaries(current_image_bw,'noholes');
    boundary.ori = B{1};
    B = [];
    boundary.ori = sortrows(boundary.ori,2);
    % plot the whole interface
    figure(1),plot(boundary.ori(:,1),boundary.ori(:,2),'.')
    axis equal
    % calculate the neck length
    boundary.temp = boundary.ori;
    boundary.temp(boundary.temp(:,2)<(image.center_x-image.delta),:)=[];
    boundary.temp(boundary.temp(:,2)>(image.center_x+image.delta),:)=[];
    boundary.upper = boundary.temp(boundary.temp(:,1)<image.center_y,:);
    boundary.lower = boundary.temp(boundary.temp(:,1)>image.center_y,:);
    % plot the neck
    figure(2),plot(boundary.temp(:,1),boundary.temp(:,2),'.')
    boundary.max = max(boundary.upper(:,1));
    boundary.min = min(boundary.lower(:,1));
    neck_length(num) = boundary.min-boundary.max;
end

%% plot the evolution of neck formation
neck_length = neck_length*image.res;
time = 0:image.dt:(image.length-1)*image.dt;
figure(3), plot(time,neck_length,'LineWidth',3,'Color','r');
title('Evolution of neck radius during coalescence');
xlabel('Time [ms]');
ylabel('Neck radius [mm]');
