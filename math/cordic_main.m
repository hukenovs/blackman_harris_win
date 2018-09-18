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
NPHI = 11;
% Set: Gain of signal (output width in HDL)
NOUT = 9;
%GAIN = 2^(NOUT-1)/1.6467;
GAIN = 2^(NOUT-1)/1.6467;



% ---- Calculate angles and create Look up table for ATAN -------------------- %
Angle(:,1) = round( atan(2.^(-(0:NOUT-1))) .* (2^(NOUT)/pi ) );
Angle(length(Angle),1) = 0;

Angle_Int = int32(Angle);
Angle_Hex = dec2hex(Angle_Int);

Magn = prod(sqrt(1+2.^(-2*(0:(NOUT)))));
% ---- Calculate quadrant from input phase ----------------------------------- %
function quad_out = find_quad(Phase, PHI, NDAT)
  z_ret = 0; r_ret = 0;
  
  if ((Phase > 0) && (Phase < 2^(PHI-1)/2)) % MSBs: "00" in HDL 
    z_ret = Phase;
  elseif ((Phase > 2^(PHI-1)/2-1) && (Phase < 2^(PHI-1))) % MSBs: "01" in HDL
    z_ret = Phase - 2^(PHI-1);
    r_ret = 1;
  elseif ((Phase > -2^(PHI-1)-1) && (Phase < -2^(PHI-1)/2)) % MSBs: "11" in HDL 
    z_ret = Phase + 2^(PHI-1);
    r_ret = 1;
  else % MSBs: "10" in HDL 
    z_ret = Phase;
  endif
  z_ret = round(z_ret * 2^(NDAT-PHI+1));
  quad_out(1,1) = int32(z_ret);
  quad_out(1,2) = int32(r_ret);
end

% ---- Calculate sin / cos values -------------------------------------------- %
function harmonic_out = find_wave(Data, Rot, LutAtan, Len, Phi)
%  sig_ret = double(Data);
  sig_ret = Data;
  cos_ret = 2^(Len+1);
  sin_ret = 0;
  
  for ii = 0:Len-1
    if (sig_ret < 0)
      sig_ret = sig_ret + LutAtan(ii+1);
      cos_new = cos_ret + floor(sin_ret * 2^(-ii));
      sin_new = sin_ret - floor(cos_ret * 2^(-ii));
%      sig_ret = sig_ret + 2^(Phi-3) * atan(2^-ii) / pi;      
    else
      sig_ret = sig_ret - LutAtan(ii+1);
      cos_new = cos_ret - floor(sin_ret * 2^(-ii));
      sin_new = sin_ret + floor(cos_ret * 2^(-ii)); 
%      sig_ret = sig_ret - 2^(Phi-3) * atan(2^-ii) / pi;     
    endif
    cos_ret = cos_new;
    sin_ret = sin_new;
  endfor
  
  if (Rot == 1)
		cos_ret = -cos_ret;
		sin_ret = -sin_ret;  
  end
  
  
  harmonic_out(1,1) = round(cos_ret / 1.6467 / 4 / 1);
  harmonic_out(1,2) = round(sin_ret / 1.6467 / 4 / 1);
end

% ---- Create phase vector and calculate sin / cos --------------------------- % 

phi_ii = -2^(NPHI-1) : 1 : 2^(NPHI-1)-1;
phi_1 = -2^(NPHI-1) : 1 : -1;
phi_2 = 0 : 1 : 2^(NPHI-1)-1;

phi_ii = [phi_2 phi_1];

for ii = 1:length(phi_ii)
  phi_out(ii,:) = find_quad(phi_ii(1,ii), NPHI, NOUT);
  sig_out(ii,:) = find_wave(phi_out(ii,1), phi_out(ii,2), Angle_Int, NOUT, NPHI);
endfor

%PhX = phi_out(:,1);
%PhY = phi_out(:,2);
PhZ = phi_out(:,1);
ReSig = sig_out(:,1);
ImSig = sig_out(:,2);

max(abs(ReSig))



% ---- Calculate spectrum for CORDIC sine / cosine --------------------------- % 
%Spec_Re = fft(ReSig, 2^(NPHI)); 
%Spec_Im = fft(ImSig, 2^(NPHI)); 
Spec_Re = fft(ReSig + 0.1 * randn(size(ReSig)), length(phi_ii)); 
Spec_Im = fft(ImSig + 0.1 * randn(size(ImSig)), length(phi_ii));
Spec_Re = Spec_Re .* conj(Spec_Re);
Spec_Im = Spec_Im .* conj(Spec_Im);

Spec_Re = fftshift(Spec_Re); 
Spec_Im = fftshift(Spec_Im);

Sabs_Re = Spec_Re / max(Spec_Re);
Sabs_Im = Spec_Im / max(Spec_Im);

Slog_Re = 10*log10(Sabs_Re);
Slog_Im = 10*log10(Sabs_Im);


% ---- Calculate ideal values of sine / cosine ------------------------------- % 
Id_sin(:,1) = round(2^(NOUT-1) * sin( ( 0: 2^NPHI-1 ) .* 2*pi/(2^NPHI)));
Id_cos(:,1) = round(2^(NOUT-1) * cos( ( 0: 2^NPHI-1 ) .* 2*pi/(2^NPHI)));

Id_sin(:,1) = Id_sin + 1 * randn(size(Id_sin));
Id_cos(:,1) = Id_cos + 1 * randn(size(Id_cos));

%Win = kaiser(length(Id_sin), 19); 
%Dat_X = filter2(Win, Id_sin);
%Dat_Y = filter2(Win, Id_cos);

Spec_Re = fft(Id_cos, length(phi_ii)); 
Spec_Im = fft(Id_sin, length(phi_ii));
Spec_Re = Spec_Re .* conj(Spec_Re);
Spec_Im = Spec_Im .* conj(Spec_Im);

Spec_Re = fftshift(Spec_Re); 
Spec_Im = fftshift(Spec_Im);

Sabs_Re = Spec_Re / max(Spec_Re);
Sabs_Im = Spec_Im / max(Spec_Im);

Sidl_Re = 10*log10(Sabs_Re);
Sidl_Im = 10*log10(Sabs_Im);

% ---- Plot figures ---------------------------------------------------------- % 
figure(1) % Plot loaded data in Freq Domain
%  subplot(1,1,1)
%  plot(ReSig, '-', 'LineWidth', 1, 'Color',[1 0 0])
%  grid on; hold on; axis ([450, 580, 2010, 2050]); 
%  plot(ImSig, '-', 'LineWidth', 1, 'Color',[0 0 1])
%  grid on; hold on; axis ([450, 580, 2010, 2050]); 
%  title(['CORDIC SINE / COSINE:'])  
%  
  subplot(4,1,1)
  plot(ReSig, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis tight; 
  plot(ImSig, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis tight; 
  title(['CORDIC SINE / COSINE:'])

  subplot(3,1,2)
  plot(Sabs_Re, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis tight; 
  plot(Sabs_Im, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis tight;   
 
  subplot(4,1,2)
  plot(Slog_Re, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis ([0, length(Slog_Re), -120, 0]); 
  plot(Slog_Im, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis ([0, length(Slog_Re), -120, 0]); 
  title(['CORDIC SPECTRUM:'])
  
  subplot(4,1,3)
  plot(Sidl_Re, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis ([0, length(Sidl_Re), -120, 0]); 
  plot(Sidl_Im, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis ([0, length(Sidl_Re), -120, 0]); 
  title(['IDEAL SPECTRUM:'])   
  
  subplot(4,1,4)
  plot(ReSig-Id_cos, '-', 'LineWidth', 1, 'Color',[1 0 0])
  grid on; hold on; axis tight; 
  plot(ImSig-Id_sin, '-', 'LineWidth', 1, 'Color',[0 0 1])
  grid on; hold on; axis tight; 
  title(['DIFF - MODEL & THEORY:'])
    
  
%% -------------------------------- EOF ------------------------------------- %% 