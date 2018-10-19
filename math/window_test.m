%% -----------------------------------------------------------------------
%
% Title       : window_functions.m
% Author      : Alexander Kapitanov	
% Company     : Insys
% E-mail      : sallador@bk.ru 
% Version     : 1.0	 
%
%-------------------------------------------------------------------------
%
% Description : 
%    Top level for testing Window functions from HLS
%
%  Parameter: WINTYPE - 
%    2 - Hamming or Hann
%    3 - Blackman_Harris 3-order
%    4 - Blackman_Harris 4-order, Nuttall, Blackman-Nuttall,
%    5 - Blackman_Harris 5-order, Flat-top
%    7 - Blackman_Harris 7-order
%
%
%
%-------------------------------------------------------------------------
%
% Version     : 1.0 
% Date        : 2018.10.10 
%
%-------------------------------------------------------------------------	  

% Preparing to work
close all;
clear all;

set(0, 'DefaultAxesFontSize', 14, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontSize', 14, 'DefaultTextFontName', 'Times New Roman'); 

WINTYPE = 5;
DATA_WIDTH = 24;

% Load output data from Vivado HLS
DT_CRD = load ("dout.dat");
DT_TST = load ("golden_dat.dat");
  
X_new(1,:) = DT_CRD(:,1);
X_gld(1,:) = DT_TST(:,1);

% Find length of vector 
N = length(X_new);


a0 = 0; a1 = 0; a2 = 0; a3 = 0; a4 = 0; a5 = 0; a6 = 0;

% -------- 2-order --------
%	> Hann:
%		a0 = 0.5; 
%		a1 = 0.5;  
%
% -------- 2-order --------
%	> Hamming:
%		a0 = 0.5434783; 
%		a1 = 1.0 - 0.5434783; 
%
% -------- 3-order --------
%	> Blackman-Harris:
%		a0 = 0.21; 
%		a1 = 0.25; 
%		a2 = 0.04; 
%
% -------- 4-order --------
%	> Blackman-Harris:
%		a0 = 0.35875; 
%		a1 = 0.48829; 
%		a2 = 0.14128; 
%		a3 = 0.01168;
%
%	> Nuttall:
%		a0 = 0.355768; 
%		a1 = 0.487396; 
%		a2 = 0.144323; 
%		a3 = 0.012604;
%
%	> Blackman-Nuttall:
%		a0 = 0.3635819; 
%		a1 = 0.4891775; 
%		a2 = 0.1365995; 
%		a3 = 0.0106411;
%
% -------- 5-order --------
%	> Blackman-Harris:
		a0 = 0.3232153788877343;
		a1 = 0.4714921439576260;
		a2 = 0.1755341299601972;
		a3 = 0.0284969901061499;
		a4 = 0.0012613570882927;

%	> Flat-top (1):
%		a0 = 0.50000;
%		a1 = 0.98500;
%		a2 = 0.64500;
%		a3 = 0.19400;
%		a4 = 0.01500;
%
%	> Flat-top (2):
%		a0 = 0.215578950;
%		a1 = 0.416631580;
%		a2 = 0.277263158;
%		a3 = 0.083578947;
% 	a4 = 0.006947368;
%	
% -------- 7-order --------
%	> Blackman-Harris:
%    a0 = 0.271220360585039;
%    a1 = 0.433444612327442;
%    a2 = 0.218004122892930;
%    a3 = 0.065785343295606;
%    a4 = 0.010761867305342;
%    a5 = 0.000770012710581;
%    a6 = 0.000013680883060;
%
% Create ideal window function array
sh_val = 1;
for i=0:N-1
  if (WINTYPE == 2) 
    Winf(i+1) = a0 - a1 * cos((2 * i * pi)/N);
  elseif (WINTYPE == 3) 
    Winf(i+1) = a0 - a1 * cos((2 * i * pi)/N) + a2 * cos((2 * 2 * i * pi)/N);
   elseif (WINTYPE == 4) 
    Winf(i+1) = a0 - a1 * cos((2 * i * pi)/N) + a2 * cos((2 * 2 * i * pi)/N) - a3 * cos((3 * 2 * i * pi)/N); 
   elseif (WINTYPE == 5) 
    Winf(i+1) = a0 - a1 * cos((2 * i * pi)/N) + a2 * cos((2 * 2 * i * pi)/N) - a3 * cos((3 * 2 * i * pi)/N) + a4 * cos((4 * 2 * i * pi)/N); 
    sh_val = 2;
  elseif (WINTYPE == 7) 
    Winf(i+1) = a0 - a1 * cos((2 * i * pi)/N) + a2 * cos((2 * 2 * i * pi)/N) - a3 * cos((3 * 2 * i * pi)/N) + a4 * cos((4 * 2 * i * pi)/N) - a5 * cos((5 * 2 * i * pi)/N) + a6 * cos((6 * 2 * i * pi)/N); 
    sh_val = 2;
  else
    Winf(i+1) = 0;
  endif
endfor
Winf = round((2^(DATA_WIDTH-sh_val)-1) * Winf);

% Plot results
figure(1) 
  subplot(3,1,1)  
  plot(X_new, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis tight; 
  plot(X_gld, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis tight; 
  title(["Window function"])    
  legend("HLS Win", "Golden", "location", "northeast");
  
  subplot(3,1,2)  
  plot(X_new-Winf, '-.', 'LineWidth', 2, 'Color',[1 0 0])
  grid on; hold on; axis tight; 
  title(["Compare HLS"])  
  legend("Diff HLS - Matlab", "location", "southeast");
  
  subplot(3,1,3)  
  plot(X_gld-Winf, '--', 'LineWidth', 2, 'Color',[0 1 0])
  grid on; hold on; axis ([0 N -1 1]); 
  title(['Compare Golden'])  
  legend("Diff Golden - Matlab", "location", "southeast");