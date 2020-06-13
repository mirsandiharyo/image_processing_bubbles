%% 
% An image processing script to determine the evolution of neck radius 
% during coalescence of two bubbles or droplets. 
% Sample and background images can be found inside the folder.
% Created by: Haryo Mirsandi

addpath('../tifflib/')
close all;
clearvars;

%% read the input file
disp('choose the input file (.txt)');
[input_name, file_path] = uigetfile('.txt');
cd(file_path);
fid = fopen(input_name);
read_line = regexp(fgetl(fid), '= ', 'split');
bg_name = read_line{2};
read_line = regexp(fgetl(fid), '= ', 'split');
series_name = read_line{2};
read_line = regexp(fgetl(fid), '=', 'split');
image.dt = str2double(read_line{2});
read_line = regexp(fgetl(fid), '=', 'split');
image.res = str2double(read_line{2});
read_line = regexp(fgetl(fid), '=', 'split');
image.start = str2double(read_line{2});
read_line = regexp(fgetl(fid), '=', 'split');
image.threshold = str2double(read_line{2});
read_line = regexp(fgetl(fid), '=', 'split');
image.center_x = str2double(read_line{2});
read_line = regexp(fgetl(fid), '=', 'split');
image.center_y = str2double(read_line{2});
read_line = regexp(fgetl(fid), '=', 'split');
image.delta = str2double(read_line{2});
fclose(fid);

%% read the images
% background image
image_background = imread(bg_name);
image_background = double(image_background);
% image series
image.info = imfinfo(series_name);
image.width = image.info.Width;
image.height = image.info.Height;
image.length = length(image.info);
image.allframe = zeros(image.height,image.width,image.length,'uint16');
image.info = [];

%% store all frames
file_id = tifflib('open',series_name,'r');
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

%% determine the neck radius
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
    % calculate the neck radius
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

%% plot the evolution of neck radius
neck_length = neck_length*image.res;
time = 0:image.dt:(image.length-1)*image.dt;
figure(3), plot(time,neck_length,'LineWidth',3,'Color','r');
title('Evolution of neck radius during coalescence');
xlabel('Time [ms]');
ylabel('Neck radius [mm]');
