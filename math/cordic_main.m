%% -------------------------------------------------------------------------- %%
%
% Title       : cordic_main.m
% Author      : Alexander Kapitanov	
% Company     : Insys
% E-mail      : sallador@bk.ru 
% Version     : 1.0	 
%
set(0, 'DefaultAxesFontSize', 14, 'DefaultAxesFontName', 'Times New Roman');
set(0, 'DefaultTextFontSize', 14, 'DefaultTextFontName', 'Times New Roman'); 

clear all;
close all;

% Set: Phase vector size (phase - is a bit-vector)
NPHI = 10;
% Set: Gain of signal (output width in HDL)
NOUT = 14;
GAIN = 2^(NOUT-1)/1.6467;


% ---- Calculate angles and create Look up table for ATAN -------------------- %
Angle = zeros(1, NOUT-1);
for ii = 1:(NOUT-1)
  if (ii < NOUT-1)
    Angle(ii) = round(atan(2^(-(ii-1))) * (2^(NPHI)/(2*pi)));
  else
    Angle(ii) = 0;
  endif  
endfor
Angle_Int = int32(Angle);

% ---- Calculate quadrant from input phase ----------------------------------- %
function quad_out = find_quad(Phase, Gain, PHI)
  x_ret = 0; y_ret = 0; z_ret = 0;
  
  if ((Phase > 0) && (Phase < 2^(PHI-2))) % MSBs: "00" in HDL
    z_ret = Phase;
    x_ret = Gain;
    y_ret = 0;
  elseif ((Phase > 2^(PHI-2)-1) && (Phase < 2^(PHI-1))) % MSBs: "01" in HDL
    z_ret = Phase - 2^(PHI-2);
    x_ret = 0;
    y_ret = Gain;
  elseif ((Phase > -2^(PHI-2)+1) && (Phase < 1)) % MSBs: "11" in HDL 
    z_ret = Phase;
    x_ret = Gain;
    y_ret = 0;
  else % MSBs: "10" in HDL 
    z_ret = Phase + 2^(PHI-2);
    x_ret = 0;
    y_ret = -Gain;    
  endif
  quad_out(1,1) = int32(x_ret);
  quad_out(1,2) = int32(y_ret);
  quad_out(1,3) = int32(z_ret);
end

% ---- Calculate sin / cos values -------------------------------------------- %
function harmonic_out = find_wave(Data, GainX, GainY, LutAtan, Len)
  sig_ret(1) = (Data);
  cos_ret(1) = (GainX);
  sin_ret(1) = (GainY);
  for ii = 1:(Len-1)
    if (sig_ret(ii) < 0)
      sig_ret(ii+1) = sig_ret(ii) + LutAtan(ii);
      cos_ret(ii+1) = cos_ret(ii) + floor(sin_ret(ii) * 2^(1-ii));
      sin_ret(ii+1) = sin_ret(ii) - floor(cos_ret(ii) * 2^(1-ii));      
    else
      sig_ret(ii+1) = sig_ret(ii) - LutAtan(ii);
      cos_ret(ii+1) = cos_ret(ii) - floor(sin_ret(ii) * 2^(1-ii));
      sin_ret(ii+1) = sin_ret(ii) + floor(cos_ret(ii) * 2^(1-ii));      
    endif
  endfor
  harmonic_out(1,1) = (cos_ret(Len-1));
  harmonic_out(1,2) = (sin_ret(Len-1));
end

% ---- Create phase vector and calculate sin / cos --------------------------- % 
phi_1 = 0:1:2^(NPHI-1)-1;
phi_2 = -2^(NPHI-1):1:-1;

%phi_ii = -2^(NPHI-1):1:2^(NPHI-1)-1;
phi_ii = [phi_1 phi_2];
phi_ii = int32(phi_ii);

for ii = 1:length(phi_ii)
  phi_out(ii,:) = find_quad(phi_ii(1,ii), GAIN, NPHI);
  sig_out(ii,:) = find_wave(phi_out(ii,3), phi_out(ii,1), phi_out(ii,2), Angle_Int, NOUT);
endfor

%PhX = phi_out(:,1);
%PhY = phi_out(:,2);
%PhZ = phi_out(:,3);
ReSig = sig_out(:,1);
ImSig = sig_out(:,2);

max(abs(ReSig))

figure(1) % Plot loaded data in Freq Domain
  plot(ReSig, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis tight; 
  plot(ImSig, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis tight; 
  title(['CORDIC SINE / COSINE:'])  
  
%% -------------------------------- EOF ------------------------------------- %% 