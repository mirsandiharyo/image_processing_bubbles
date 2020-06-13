%% 
% An image processing script to determine the volume and trajectory
% of a moving two dimensional axisymmetric bubble or droplet.
% Sample images can be found inside the folder.
% Created by: Haryo Mirsandi

addpath('../tifflib/')
close all;
clearvars;

%% read the image series
disp('choose the input file (.txt)');
[input_name, file_path] = uigetfile('.txt');
cd(file_path);
fid = fopen(input_name);
read_line = regexp(fgetl(fid), '= ', 'split');
file_name = read_line{2};
read_line = regexp(fgetl(fid), '=', 'split');
image.dt = str2double(read_line{2});
read_line = regexp(fgetl(fid), '=', 'split');
image.res = str2double(read_line{2});
read_line = regexp(fgetl(fid), '=', 'split');
image.start = str2double(read_line{2});
read_line = regexp(fgetl(fid), '=', 'split');
image.threshold = str2double(read_line{2});
fclose(fid);

% get image information
image.info = imfinfo(file_name);
image.width = image.info.Width;
image.height = image.info.Height;
image.length = length(image.info);
image.allframe = zeros(image.height,image.width,image.length,'uint16');
image.info = [];

%% store all frames
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

%% determine the bubble properties
% initialize the variables
[bub.volume, bub.diameter, bub.center_x, bub.center_y] = ...
    deal(zeros(1,image.length));

for num = image.start:image.length
    % get the current frame and perform binarization
    current_image = double(image.allframe(:,:,num));
    current_image_bw = imbinarize(current_image,image.threshold);
    figure(1), imshow(current_image_bw);
    % get the region properties
    img_prop = regionprops(current_image_bw,'Centroid');
    % split the bubect at the center
    image_size = size(current_image_bw);
    split_center = [img_prop.Centroid(1) 1 image_size(2)-img_prop.Centroid(1) ...
        image_size(1)];
    split_image = imcrop(current_image_bw, split_center);
    % get the region properties after splitting
    split_img_prop = regionprops(split_image,'Centroid','Area');
    
    % calculate the volume using Pappus theorem
    bub.volume(num) = split_img_prop.Area*2*pi*split_img_prop.Centroid(1);
    bub.center_x(num) = img_prop.Centroid(1);
    bub.center_y(num) = img_prop.Centroid(2);
end

%% post-processing
time = 0:image.dt:(image.length-1)*image.dt;
% convert to milimeter size
bub.center_x = bub.center_x*image.res;
bub.center_y = bub.center_y*image.res;
bub.volume = bub.volume*(image.res^3);
bub.diameter = (bub.volume*6/pi).^(1./3);
bub.center_x = bsxfun(@minus,bub.center_x,bub.center_x(1));
bub.center_y = bsxfun(@minus,bub.center_y,bub.center_y(1));
bub.center_y = abs(bub.center_y);
% calculate velocity
bub.vel_x = bub.center_x(2:end)-bub.center_x(1:end-1);
bub.vel_x = bub.vel_x/image.dt;
bub.vel_y = bub.center_y(2:end)-bub.center_y(1:end-1);
bub.vel_y = bub.vel_y/image.dt;

%% plotting
% plot the bubble properties
figure(2)
subplot(3,2,1)
plot(time,bub.center_x,'k','linew',3);
xlabel('Time [ms]'), ylabel('Centroid x [mm]');
subplot(3,2,2)
plot(time,bub.center_y,'r','linew',3);
xlabel('Time [ms]'), ylabel('Centroid y [mm]');
subplot(3,2,3)
plot(time(2:end),bub.vel_x,'k','linew',3);
xlabel('Time [ms]'), ylabel('Velocity x [m/s]');
subplot(3,2,4)
plot(time(2:end),bub.vel_y,'r','linew',3);
xlabel('Time [ms]'), ylabel('Velocity y [m/s]');
subplot(3,2,5)
plot(time,bub.volume,'b','linew',3);
xlabel('Time [ms]'), ylabel('Volume [mm^3]');
subplot(3,2,6)
plot(time,bub.diameter,'g','linew',3);
xlabel('Time [ms]'), ylabel('Diameter [mm]');